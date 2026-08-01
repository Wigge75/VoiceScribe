// SystemAudioTapSpike.swift
// SPIKE — nicht für Produktion gedacht.
//
// Testet, ob Core Audios Process-Tap-API (AudioHardwareCreateProcessTap,
// ab macOS 14.2) innerhalb unserer App-Sandbox funktioniert, um gezielt den
// System-Ton eines einzelnen Prozesses (Zoom/Teams) abzugreifen — ohne den
// ScreenCaptureKit-Umweg über einen Video-Stream.
//
// Referenz-Implementierung: github.com/insidegui/AudioCap (Apple-Engineer-
// Sample, läuft nachweislich mit app-sandbox=true + audio-input=true).
//
// Nach Auswertung des Tests: entweder zum echten Meeting-Feature ausbauen
// oder diese Datei wieder vollständig entfernen.
//
// Nur in Debug-Builds enthalten — komplett aus Release-Builds ausgeschlossen.
#if DEBUG

import Foundation
import AppKit
import AudioToolbox
import AVFoundation
import OSLog

private let spikeLogger = Logger(subsystem: "com.stefanwiggeshoff.VoiceScribe", category: "SystemAudioTapSpike")

// MARK: - Minimal Core Audio Helpers

private struct SpikeError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static let unknown = kAudioObjectUnknown
    var isValid: Bool { self != .unknown }
}

private func readProcessList() throws -> [AudioObjectID] {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope:    kAudioObjectPropertyScopeGlobal,
        mElement:  kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    var err = AudioObjectGetPropertyDataSize(AudioObjectID.system, &address, 0, nil, &dataSize)
    guard err == noErr else { throw SpikeError(message: "Prozessliste (Size) fehlgeschlagen: \(err)") }

    var value = [AudioObjectID](repeating: .unknown, count: Int(dataSize) / MemoryLayout<AudioObjectID>.size)
    err = AudioObjectGetPropertyData(AudioObjectID.system, &address, 0, nil, &dataSize, &value)
    guard err == noErr else { throw SpikeError(message: "Prozessliste fehlgeschlagen: \(err)") }
    return value
}

private func readProperty<T>(_ objectID: AudioObjectID, _ selector: AudioObjectPropertySelector, defaultValue: T) throws -> T {
    var address = AudioObjectPropertyAddress(
        mSelector: selector,
        mScope:    kAudioObjectPropertyScopeGlobal,
        mElement:  kAudioObjectPropertyElementMain
    )
    var dataSize: UInt32 = 0
    var err = AudioObjectGetPropertyDataSize(objectID, &address, 0, nil, &dataSize)
    guard err == noErr else { throw SpikeError(message: "Property \(selector) (Size) fehlgeschlagen: \(err)") }

    var value = defaultValue
    err = withUnsafeMutablePointer(to: &value) { ptr in
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, ptr)
    }
    guard err == noErr else { throw SpikeError(message: "Property \(selector) fehlgeschlagen: \(err)") }
    return value
}

// MARK: - SystemAudioTapSpike

@available(macOS 14.2, *)
@MainActor
final class SystemAudioTapSpike: ObservableObject {

    @Published var statusText = "Nicht gestartet"

    private var processTapID: AudioObjectID = .unknown
    private var aggregateDeviceID: AudioObjectID = .unknown
    private var deviceProcID: AudioDeviceIOProcID?
    private let queue = DispatchQueue(label: "SystemAudioTapSpike")

    var isRunning: Bool { processTapID.isValid }

    // MARK: Start / Stop

    func start() {
        guard !isRunning else { return }
        do {
            guard let target = try findTargetProcess() else {
                statusText = "Kein laufendes Zoom/Teams gefunden"
                spikeLogger.notice("Kein Zoom/Teams-Prozess gefunden")
                return
            }
            spikeLogger.notice("Ziel-Prozess: \(target.name, privacy: .public)")

            let tapDescription = CATapDescription(stereoMixdownOfProcesses: [target.objectID])
            tapDescription.uuid = UUID()
            tapDescription.muteBehavior = .unmuted

            var tapID: AudioObjectID = .unknown
            var err = AudioHardwareCreateProcessTap(tapDescription, &tapID)
            guard err == noErr else {
                statusText = "Tap-Erstellung fehlgeschlagen (\(err))"
                spikeLogger.error("AudioHardwareCreateProcessTap fehlgeschlagen: \(err)")
                return
            }
            processTapID = tapID
            spikeLogger.notice("Process Tap erstellt: #\(tapID)")

            let systemOutputID: AudioObjectID = try readProperty(
                .system, kAudioHardwarePropertyDefaultSystemOutputDevice, defaultValue: .unknown)
            let outputUID: String = try readProperty(
                systemOutputID, kAudioDevicePropertyDeviceUID, defaultValue: "" as CFString) as String

            let aggregateDescription: [String: Any] = [
                kAudioAggregateDeviceNameKey: "VoiceScribe-Tap-Spike",
                kAudioAggregateDeviceUIDKey: UUID().uuidString,
                kAudioAggregateDeviceMainSubDeviceKey: outputUID,
                kAudioAggregateDeviceIsPrivateKey: true,
                kAudioAggregateDeviceIsStackedKey: false,
                kAudioAggregateDeviceTapAutoStartKey: true,
                kAudioAggregateDeviceSubDeviceListKey: [
                    [kAudioSubDeviceUIDKey: outputUID]
                ],
                kAudioAggregateDeviceTapListKey: [
                    [
                        kAudioSubTapDriftCompensationKey: true,
                        kAudioSubTapUIDKey: tapDescription.uuid.uuidString
                    ]
                ]
            ]

            var aggregateID: AudioObjectID = .unknown
            err = AudioHardwareCreateAggregateDevice(aggregateDescription as CFDictionary, &aggregateID)
            guard err == noErr else {
                statusText = "Aggregate-Device fehlgeschlagen (\(err))"
                spikeLogger.error("AudioHardwareCreateAggregateDevice fehlgeschlagen: \(err)")
                cleanup()
                return
            }
            aggregateDeviceID = aggregateID
            spikeLogger.notice("Aggregate Device erstellt: #\(aggregateID)")

            var format: AudioStreamBasicDescription = try readProperty(
                tapID, kAudioTapPropertyFormat, defaultValue: AudioStreamBasicDescription())
            guard let avFormat = AVAudioFormat(streamDescription: &format) else {
                statusText = "Audioformat ungültig"
                spikeLogger.error("AVAudioFormat-Erstellung aus Tap-Format fehlgeschlagen")
                cleanup()
                return
            }
            spikeLogger.notice("Tap-Format: \(String(describing: avFormat), privacy: .public)")

            err = AudioDeviceCreateIOProcIDWithBlock(&deviceProcID, aggregateID, queue) { [weak self] _, inputData, _, _, _ in
                guard let self, let buffer = AVAudioPCMBuffer(pcmFormat: avFormat, bufferListNoCopy: inputData, deallocator: nil) else { return }
                self.logLevel(of: buffer)
            }
            guard err == noErr, let procID = deviceProcID else {
                statusText = "IOProc-Erstellung fehlgeschlagen (\(err))"
                spikeLogger.error("AudioDeviceCreateIOProcIDWithBlock fehlgeschlagen: \(err)")
                cleanup()
                return
            }

            err = AudioDeviceStart(aggregateID, procID)
            guard err == noErr else {
                statusText = "Start fehlgeschlagen (\(err))"
                spikeLogger.error("AudioDeviceStart fehlgeschlagen: \(err)")
                cleanup()
                return
            }

            statusText = "Läuft — Ziel: \(target.name)"
            spikeLogger.notice("Tap läuft für \(target.name, privacy: .public)")
        } catch {
            statusText = "Fehler: \(error.localizedDescription)"
            spikeLogger.error("Spike-Fehler: \(error.localizedDescription, privacy: .public)")
            cleanup()
        }
    }

    func stop() {
        cleanup()
        statusText = "Gestoppt"
    }

    // MARK: Private

    private func cleanup() {
        if aggregateDeviceID.isValid, let procID = deviceProcID {
            AudioDeviceStop(aggregateDeviceID, procID)
            AudioDeviceDestroyIOProcID(aggregateDeviceID, procID)
        }
        deviceProcID = nil
        if aggregateDeviceID.isValid {
            AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            aggregateDeviceID = .unknown
        }
        if processTapID.isValid {
            AudioHardwareDestroyProcessTap(processTapID)
            processTapID = .unknown
        }
    }

    private func logLevel(of buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        guard frameLength > 0 else { return }
        var peak: Float = 0
        for sample in 0..<frameLength {
            peak = max(peak, abs(channelData[0][sample]))
        }
        let db = peak > 0 ? 20 * log10(peak) : -160
        let dbString = String(format: "%.1f", db)
        spikeLogger.notice("Pegel: \(dbString, privacy: .public) dB")
    }

    private struct TargetProcess {
        let objectID: AudioObjectID
        let name: String
    }

    /// Sucht in der Liste laufender Audio-Prozesse nach Zoom oder Teams
    /// (per Bundle-ID/Namen-Substring — bewusst grob für den Spike).
    private func findTargetProcess() throws -> TargetProcess? {
        let keywords = ["zoom", "teams"]
        let runningApps = NSWorkspace.shared.runningApplications

        for objectID in try readProcessList() {
            let pid: pid_t = (try? readProperty(objectID, kAudioProcessPropertyPID, defaultValue: pid_t(-1))) ?? -1
            guard pid > 0, let app = runningApps.first(where: { $0.processIdentifier == pid }) else { continue }

            let name = app.localizedName ?? ""
            let bundleID = app.bundleIdentifier ?? ""
            if keywords.contains(where: { name.lowercased().contains($0) || bundleID.lowercased().contains($0) }) {
                return TargetProcess(objectID: objectID, name: name.isEmpty ? bundleID : name)
            }
        }
        return nil
    }
}

#endif // DEBUG

// OllamaService.swift
// Communicates with Ollama in two ways:
//
// Status / model list  →  HTTP GET to 127.0.0.1:11434 (lightweight, no streaming)
//
// Text revision        →  Process: runs the `ollama` binary directly as a
//                         subprocess and pipes the prompt through stdin.
//                         This completely bypasses URLSession and avoids the
//                         kCFStreamErrorHTTPParseFailure (-2102) that occurs
//                         when URLSession tries to parse Ollama's chunked
//                         HTTP streaming responses.
//
// Ollama must be installed: https://ollama.com
// Binary locations checked: /opt/homebrew/bin/ollama (Apple Silicon) or /usr/local/bin/ollama (Intel)

import Foundation
import os

// MARK: - Errors

enum OllamaError: LocalizedError {
    case notRunning
    case binaryNotFound
    case noModelSelected
    case requestFailed(Int)
    case emptyResponse
    case timeout

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Ollama läuft nicht. Terminal: ollama serve"
        case .binaryNotFound:
            return "Ollama nicht gefunden. Installiere Ollama unter https://ollama.com"
        case .noModelSelected:
            return "Kein Modell ausgewählt. Einstellungen → Modelle"
        case .requestFailed(let code):
            return "Ollama-Fehler (Code \(code))"
        case .emptyResponse:
            return "Ollama hat keinen Text zurückgegeben"
        case .timeout:
            return "Ollama hat nicht geantwortet (Timeout nach 30 Sek.)"
        }
    }
}

// MARK: - Response Types (used for status / model list only)

private struct OllamaTagsResponse: Decodable {
    let models: [OllamaModelEntry]
}
private struct OllamaModelEntry: Decodable {
    let name: String
}

// MARK: - OllamaService

final class OllamaService {

    // -------------------------------------------------------------------------
    // HTTP session — used ONLY for lightweight status/model-list requests.
    // Proxy disabled so VPNs can't intercept localhost connections.
    // -------------------------------------------------------------------------
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.connectionProxyDictionary = [:]
        return URLSession(configuration: config)
    }()

    private let baseURL = URL(string: "http://127.0.0.1:11434")!

    // Common install locations for the Ollama binary on macOS
    private let ollamaBinaryPaths = [
        "/usr/local/bin/ollama",
        "/opt/homebrew/bin/ollama"
    ]

    // Tracks the server process only when started by this app instance
    private var serverProcess: Process? = nil

    /// True if the Ollama server was started by this app (and can be stopped by it).
    var isManagedByApp: Bool { serverProcess != nil }

    // MARK: - Server Lifecycle

    /// Starts `ollama serve` as a background process.
    /// Returns true if the server is reachable after startup.
    @discardableResult
    func startServer() async -> Bool {
        guard serverProcess == nil else { return await isRunning() }

        guard let binaryPath = ollamaBinaryPaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else { return false }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["serve"]
        process.environment = [
            "HOME": NSHomeDirectory(),
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
        ]
        // Discard stdout/stderr so the subprocess doesn't inherit the app's streams
        process.standardOutput = FileHandle.nullDevice
        process.standardError  = FileHandle.nullDevice

        process.terminationHandler = { [weak self] _ in
            self?.serverProcess = nil
        }

        do {
            try process.run()
            serverProcess = process
        } catch {
            return false
        }

        // Give the server ~1.5 seconds to bind its port before checking
        try? await Task.sleep(for: .milliseconds(1500))
        return await isRunning()
    }

    /// Stops the Ollama server if it was started by this app.
    func stopServer() {
        serverProcess?.terminate()
        serverProcess = nil
    }

    // MARK: - Status

    func isRunning() async -> Bool {
        let url = baseURL.appendingPathComponent("api/version")
        var req = URLRequest(url: url, timeoutInterval: 2.0)
        req.httpMethod = "GET"
        do {
            let (_, response) = try await session.data(for: req)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func availableModels() async throws -> [String] {
        guard await isRunning() else { throw OllamaError.notRunning }
        let url = baseURL.appendingPathComponent("api/tags")
        let (data, _) = try await session.data(from: url)
        let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return decoded.models.map { $0.name }
    }

    // MARK: - Text Revision (subprocess)

    /// Revises text by piping the prompt to the `ollama run` binary via stdin.
    ///
    /// Flow:  prompt → stdin → ollama run <model> → stdout → revised text
    ///
    /// The subprocess communicates with the running Ollama server internally,
    /// so `ollama serve` must still be running — but our app no longer has to
    /// deal with HTTP parsing or URLSession streaming.
    ///
    /// Environment variables:
    ///   TERM=dumb     — prevents terminal control sequences / ANSI escape codes
    ///   NO_COLOR=1    — disables color output (used by many CLIs)
    ///   TERM_PROGRAM  — cleared so ollama doesn't detect an "advanced" terminal
    func revise(text: String, model: String, style: RevisionStyle) async throws -> String {
        guard !model.isEmpty else { throw OllamaError.noModelSelected }

        guard let binaryPath = ollamaBinaryPaths.first(where: {
            FileManager.default.isExecutableFile(atPath: $0)
        }) else {
            throw OllamaError.binaryNotFound
        }

        let prompt = buildPrompt(for: text, style: style)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: binaryPath)
            process.arguments     = ["run", "--nowordwrap", model]

            // Minimal environment: HOME so ollama can find its models,
            // PATH so any child processes resolve correctly.
            // TERM=dumb + NO_COLOR=1 prevent ANSI escape codes in stdout.
            process.environment = [
                "HOME":         NSHomeDirectory(),
                "PATH":         "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
                "TERM":         "dumb",
                "NO_COLOR":     "1",
                "TERM_PROGRAM": ""
            ]

            let inputPipe  = Pipe()
            let outputPipe = Pipe()
            let errorPipe  = Pipe()
            process.standardInput  = inputPipe
            process.standardOutput = outputPipe
            process.standardError  = errorPipe

            // Race-Condition-Schutz: stellt sicher dass continuation nur einmal aufgerufen wird.
            // OSAllocatedUnfairLock ist Sendable und damit Swift-6-konform.
            let didFinish = OSAllocatedUnfairLock(initialState: false)

            @Sendable func finish(with result: Result<String, Error>) {
                let shouldProceed = didFinish.withLock { state in
                    guard !state else { return false }
                    state = true
                    return true
                }
                guard shouldProceed else { return }
                switch result {
                case .success(let text): continuation.resume(returning: text)
                case .failure(let err):  continuation.resume(throwing: err)
                }
            }

            // 30-Sekunden-Timeout — terminiert den Prozess falls er hängt.
            let timer = DispatchSource.makeTimerSource(queue: .global())
            timer.schedule(deadline: .now() + 30)
            timer.setEventHandler {
                timer.cancel()
                if process.isRunning { process.terminate() }
                finish(with: .failure(OllamaError.timeout))
            }
            timer.resume()

            process.terminationHandler = { _ in
                timer.cancel()
                let data   = outputPipe.fileHandleForReading.readDataToEndOfFile()
                var output = String(data: data, encoding: .utf8) ?? ""

                // Belt-and-suspenders: strip any residual ANSI sequences
                output = output.replacingOccurrences(
                    of: #"\x1B\[[\[(]?[0-9;?]*[a-zA-Z]"#,
                    with: "",
                    options: .regularExpression
                )
                // Strip standalone ESC characters
                output = output.replacingOccurrences(of: "\u{1B}", with: "")
                output = output.trimmingCharacters(in: .whitespacesAndNewlines)

                if output.isEmpty {
                    let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    let errMsg  = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    print("[OllamaService] stderr: \(errMsg)")
                    finish(with: .failure(OllamaError.emptyResponse))
                } else {
                    finish(with: .success(output))
                }
            }

            do {
                try process.run()
                inputPipe.fileHandleForWriting.write(Data(prompt.utf8))
                inputPipe.fileHandleForWriting.closeFile()
            } catch {
                timer.cancel()
                finish(with: .failure(error))
            }
        }
    }

    // MARK: - Prompt

    private func buildPrompt(for text: String, style: RevisionStyle) -> String {
        "\(style.systemPrompt)\n\nText: \(text)"
    }
}

# VoiceScribe

Lokale Sprach-Diktiersoftware für macOS als Menu-Bar-App.

**Aktuelle Version:** 2.1.1

- **Diktat-Modus**: Sprache → Whisper → Text in Zwischenablage (oder direkt einfügen)
- **Überarbeitungs-Modus**: Sprache → Whisper → Apple Intelligence verfeinert → Text in Zwischenablage (oder direkt einfügen)
- **Auto-Paste**: Text wird direkt in das zuletzt fokussierte Eingabefeld eingefügt — kein manuelles ⌘V nötig
- **Anpassbare Prompts**: Die KI-Anweisungen für jeden Überarbeitungs-Stil sind direkt in der App editierbar
- **System-Setup**: Mikrofon, Bedienungshilfen, Auto-Paste und Apple Intelligence an einem Ort prüfen
- Vollständig offline nach dem ersten Modell-Download
- Kein Cloud-Dienst, keine Datenübertragung

---

## Voraussetzungen

| Anforderung | Version |
|---|---|
| macOS | **26 (Tahoe)** oder neuer |
| Chip | Apple Silicon (M1 oder neuer) |
| Apple Intelligence | Aktiviert in Systemeinstellungen → Apple Intelligence |

> **Hinweis:** Apple Intelligence muss einmalig in den Systemeinstellungen aktiviert werden. Ohne Apple Intelligence ist der Überarbeitungs-Modus nicht verfügbar — der Diktat-Modus funktioniert auf jedem Apple-Silicon-Mac.

---

## Installation

### Einfach: Fertiger Download (empfohlen)

1. [Neueste Version herunterladen](https://github.com/Wigge75/VoiceScribe/releases/latest) → **VoiceScribe.zip**
2. ZIP entpacken → `VoiceScribe.app` in den Ordner `/Programme` ziehen
3. Beim ersten Start: **Rechtsklick → Öffnen** — oder Systemeinstellungen → Datenschutz & Sicherheit → „Trotzdem öffnen"

> **Warum die Sicherheitswarnung?** macOS warnt bei Apps, die nicht über den App Store verteilt werden. VoiceScribe läuft vollständig lokal — keine Daten verlassen deinen Mac.

### Aus dem Quellcode bauen

```bash
git clone https://github.com/Wigge75/VoiceScribe.git
cd VoiceScribe
open VoiceScribe.xcodeproj
```

In Xcode: **Signing & Capabilities** → Team auswählen → **Cmd+R**

---

## Berechtigungen beim ersten Start

| Berechtigung | Wann | Warum |
|---|---|---|
| **Mikrofon** | Beim ersten Drücken des Tastenkürzel | Aufnahme |
| **Bedienungshilfen** | Beim Aktivieren von Auto-Paste im Tab **System** | Text direkt in andere Apps einfügen |

Beide Berechtigungen werden einmalig angefragt und bleiben dauerhaft gespeichert. Den aktuellen Status findest du in **Einstellungen (⌘,) → System**.

---

## Verwendung

### Tastenkürzel

| Aktion | Standard-Kürzel |
|---|---|
| Aufnahme starten/stoppen | **⌥Space** |
| Modus wechseln (Diktat ↔ Überarbeiten) | **⌥0** |
| Stil: Beruflich | **⌥1** |
| Stil: Locker | **⌥2** |
| Stil: Mit Emojis | **⌥3** |
| Einstellungen öffnen | **⌘,** |

Alle Tastenkürzel sind in den Einstellungen frei konfigurierbar.  
Die Stil-Shortcuts (⌥1/⌥2/⌥3) wechseln automatisch in den Überarbeitungs-Modus.

### Ablauf

**Diktat:**
1. In das gewünschte Textfeld klicken (z.B. WhatsApp, Mail, Notes)
2. **⌥Space** halten → Panel erscheint, Aufnahme startet
3. Sprechen
4. **⌥Space** loslassen → Transkription startet
5. Text landet in der Zwischenablage — bei aktiviertem Auto-Paste direkt im Textfeld

**Überarbeitung:**
1. In das gewünschte Textfeld klicken
2. **⌥Space** halten → Panel erscheint, Aufnahme startet
3. Sprechen
4. **⌥Space** loslassen → Whisper transkribiert, Apple Intelligence verfeinert
5. Text landet in der Zwischenablage — bei aktiviertem Auto-Paste direkt im Textfeld

### Auto-Paste

Mit aktiviertem Auto-Paste entfällt das manuelle ⌘V:

1. **Einstellungen (⌘,) → System → „Text automatisch einfügen"** aktivieren
2. Beim ersten Aktivieren öffnen sich die Systemeinstellungen → VoiceScribe unter **Bedienungshilfen** freigeben
3. Ab sofort wird der transkribierte Text direkt in das zuletzt fokussierte Eingabefeld eingefügt

> **Datenschutz:** VoiceScribe markiert den Clipboard-Inhalt mit dem `org.nspasteboard.ConcealedType`-Flag — Clipboard-Manager wie Alfred oder Raycast überspringen den Inhalt automatisch.

### Modus wechseln

- **Tastenkürzel**: ⌥0 togglet zwischen Diktat und Überarbeiten
- **Menüleiste**: VoiceScribe-Icon klicken → Modus auswählen
- **Einstellungen**: ⌘, → Tab „Allgemein"

Bei jedem Wechsel per Tastenkürzel erscheint kurz ein Icon-Overlay zur Bestätigung.

---

## KI-Überarbeitung (Überarbeitungs-Modus)

VoiceScribe nutzt **Apple Intelligence** für die Textüberarbeitung — vollständig lokal auf dem Neural Engine, kein Server, keine Installation.

**Voraussetzung:** Apple Intelligence muss in Systemeinstellungen → Apple Intelligence aktiviert sein.

### Überarbeitungs-Stile

| Stil | Kürzel | Beschreibung |
|---|---|---|
| **Beruflich** | ⌥1 | Klares, strukturiertes Schriftdeutsch für Teams, E-Mails, Berichte |
| **Locker** | ⌥2 | Natürliche Textnachricht, informell und direkt |
| **Mit Emojis** | ⌥3 | Locker mit passenden Emojis |

### Prompts anpassen

Die KI-Anweisungen (System-Prompts) für jeden Stil sind in den Einstellungen editierbar:

1. **⌘, → Tab „Prompts"** öffnen
2. Stil oben auswählen (Beruflich / Locker / Mit Emojis)
3. Prompt im Textfeld bearbeiten
4. **„Speichern"** klicken — der Button ist nur aktiv, wenn es ungespeicherte Änderungen gibt

Die Prompts werden dauerhaft gespeichert und beim nächsten Start wiederhergestellt. Ein leerer Prompt kann nicht gespeichert werden.

---

## Einstellungen

| Einstellung | Tab | Beschreibung |
|---|---|---|
| Mikrofon-Freigabe | System | Status prüfen oder macOS-Datenschutzeinstellungen öffnen |
| Bedienungshilfen | System | Erforderlich für Auto-Paste |
| Text automatisch einfügen | System | Auto-Paste nach Transkription |
| Apple Intelligence | System | Hinweis zur lokalen KI-Überarbeitung |
| Tastenkürzel | Allgemein | Globales Hotkey für Aufnahme + Stil/Modus-Shortcuts |
| Modus | Allgemein | Diktat oder Überarbeiten |
| Standard-Stil | Allgemein | Beruflich / Locker / Mit Emojis |
| Sprache | Allgemein | Deutsch / Englisch / Auto-Erkennung usw. |
| Whisper-Modell | Allgemein | Schnell bis Beste Qualität |
| System-Prompts | Prompts | KI-Anweisungen pro Überarbeitungs-Stil frei editierbar |

---

## Whisper-Modelle

| Modell | Größe | Empfehlung |
|---|---|---|
| Schnell | ~150 MB | Sehr schnell, ausreichend für einfache Texte |
| Ausgewogen | ~216 MB | Empfohlen für normale Nutzung |
| Beste Qualität | ~632 MB | Höchste Genauigkeit, etwas langsamer |

Das Modell wird beim ersten Start automatisch heruntergeladen (Internetverbindung nötig).  
Den Fortschritt siehst du in **Einstellungen → Allgemein → Whisper-Modell**:
- **Lädt herunter… X%** — einmaliger Download
- **Modell wird kompiliert…** — einmalige CoreML-Spezialisierung für deinen Chip (~2 Min.)

Danach vollständig offline.

---

## Fehlerbehebung

### „KI nicht verfügbar"
→ Apple Intelligence ist nicht aktiviert: **Systemeinstellungen → Apple Intelligence → aktivieren**  
→ Oder: Dein Gerät ist nicht kompatibel (Intel-Mac oder Apple Silicon vor M1)

### Auto-Paste funktioniert nicht
→ Bedienungshilfen-Berechtigung fehlt: **Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → VoiceScribe aktivieren**

### Whisper-Modell lädt nicht
→ Internetverbindung beim ersten Start erforderlich. Danach vollständig offline.  
→ Fortschritt in **Einstellungen (⌘,) → Allgemein → Whisper-Modell** sichtbar.

### App erscheint nicht in der Menüleiste
→ App neu starten.

---

## Deinstallation

1. VoiceScribe beenden (Menüleiste → „VoiceScribe beenden")
2. `VoiceScribe.app` in den Papierkorb
3. Optional Modelle löschen: `rm -rf ~/Library/Containers/com.stefanwiggeshoff.VoiceScribe/Data/Library/Caches/`
4. Optional Einstellungen löschen: `defaults delete com.stefanwiggeshoff.VoiceScribe`

---

## Technologie

- **Swift** / **SwiftUI** / **AppKit**
- **WhisperKit** — lokale Spracherkennung via Apple Neural Engine (Core ML)
- **FoundationModels** — Apple Intelligence on-device KI (macOS 26+)
- **AVFoundation** — Mikrofon-Aufnahme
- **KeyboardShortcuts** — globale Tastenkürzel
- Kein Cloud-Dienst, keine Telemetrie, alle Daten bleiben lokal

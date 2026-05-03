# VoiceScribe

Lokale Sprach-Diktiersoftware für macOS als Menu-Bar-App.

- **Diktat-Modus**: Sprache → Whisper → Text direkt eingefügt
- **Überarbeitungs-Modus**: Sprache → Whisper → KI verfeinert → Text eingefügt
- Vollständig offline nach dem ersten Modell-Download
- Kein Cloud-Dienst, keine Datenübertragung

---

## Voraussetzungen

| Anforderung | Version |
|---|---|
| macOS | **26 (Tahoe)** oder neuer |
| Chip | Apple Silicon (M1 oder neuer) |

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

**Mikrofon**: Wird einmalig beim ersten Drücken des Tastenkürzel angefragt.

**Bedienungshilfen** (für direktes Text-Einfügen):
1. Systemeinstellungen → **Datenschutz & Sicherheit** → **Bedienungshilfen**
2. **VoiceScribe** in der Liste aktivieren

Alternativ: Einstellungen (⌘,) → Tab „Allgemein" → „Erlauben…"-Button.

---

## Verwendung

### Tastenkürzel

| Aktion | Standard-Kürzel |
|---|---|
| Aufnahme starten/stoppen | **⌥Space** (Option + Leertaste) |
| Einstellungen öffnen | **⌘,** |

Das Tastenkürzel ist in den Einstellungen frei konfigurierbar.

### Ablauf

1. Cursor in ein Textfeld setzen (z. B. Mail, Slack, Browser, TextEdit)
2. **⌥Space** drücken → Panel erscheint
3. Sprechen
4. **⌥Space** nochmals drücken → Text wird transkribiert und eingefügt

### Modus wechseln

Im Menüleisten-Icon klicken → **Diktat** oder **Überarbeiten** auswählen.

---

## KI-Überarbeitung (Überarbeitungs-Modus)

VoiceScribe nutzt zwei KI-Engines — automatisch, ohne Konfiguration:

| Engine | Voraussetzung | Geschwindigkeit |
|---|---|---|
| **Apple Intelligence** | macOS 26+, aktiviert in Systemeinstellungen | sehr schnell |
| **Ollama** (Fallback) | Ollama installiert und gestartet | abhängig vom Modell |

Auf macOS 26 mit Apple Intelligence ist **kein Setup nötig** — die KI läuft on-device.

### Überarbeitungs-Stile

| Stil | Beschreibung |
|---|---|
| **Beruflich** | Klares, strukturiertes Schriftdeutsch für Teams, E-Mails, Berichte |
| **Locker** | Natürliche Textnachricht, informell und direkt |
| **Mit Emojis** | Locker mit passenden Emojis |
| **Entschärfen** | Wütenden oder aggressiven Text in sachlichen Ton umwandeln |

---

## Ollama einrichten (optional, Fallback)

Nur nötig wenn Apple Intelligence nicht verfügbar ist.

```bash
# Ollama installieren
brew install ollama

# Modell herunterladen
ollama pull mistral
```

Den Ollama-Server kannst du direkt in VoiceScribe starten und stoppen:  
**Einstellungen (⌘,) → Tab „Modelle" → „Ollama starten" / „Ollama stoppen"**

---

## Einstellungen

| Einstellung | Beschreibung |
|---|---|
| Tastenkürzel | Globales Hotkey für Aufnahme |
| Modus | Diktat oder Überarbeiten |
| Standard-Stil | Beruflich / Locker / Mit Emojis / Entschärfen |
| Sprache | Deutsch / Englisch / Auto-Erkennung usw. |
| Whisper-Modell | Tiny (schnell) bis Medium (genau) |
| Ollama | Server starten/stoppen, Modell auswählen |

---

## Whisper-Modelle

| Modell | Größe | Empfehlung |
|---|---|---|
| Tiny | ~150 MB | Sehr schnell, ausreichend für einfache Texte |
| Base | ~300 MB | Gute Balance aus Geschwindigkeit und Qualität |
| Small | ~500 MB | Empfohlen für normale Nutzung |
| Medium | ~1,5 GB | Beste Qualität, langsamer |

Das Modell wird beim ersten Start automatisch heruntergeladen (Internetverbindung nötig).  
Danach vollständig offline.

> **Hinweis:** Die erste Transkription dauert etwas länger — macOS kompiliert das Modell einmalig für deinen Chip. Ab der zweiten Transkription ist alles deutlich schneller.

---

## Fehlerbehebung

### Text wird nicht eingefügt
→ Bedienungshilfen-Berechtigung prüfen: Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen

### „Ollama läuft nicht"
→ Einstellungen (⌘,) → Tab „Modelle" → „Ollama starten" klicken  
→ Oder Terminal: `ollama serve`

### Whisper-Modell lädt nicht
→ Internetverbindung beim ersten Start erforderlich. Danach vollständig offline.

### App erscheint nicht in der Menüleiste
→ App neu starten. Bei Installation aus Xcode: App läuft im DerivedData-Ordner.

---

## Deinstallation

1. VoiceScribe beenden (Menüleiste → „VoiceScribe beenden")
2. `VoiceScribe.app` in den Papierkorb
3. Optional Caches löschen: `rm -rf ~/Library/Caches/com.stefanwiggeshoff.VoiceScribe`
4. Optional Einstellungen löschen: `defaults delete com.stefanwiggeshoff.VoiceScribe`

---

## Technologie

- **Swift** / **SwiftUI** / **AppKit**
- **WhisperKit** — lokale Spracherkennung via Apple Neural Engine (Core ML)
- **FoundationModels** — Apple Intelligence on-device KI (macOS 26+)
- **Ollama** — lokaler LLM-Dienst als Fallback
- **AVFoundation** — Mikrofon-Aufnahme
- **KeyboardShortcuts** — globale Tastenkürzel
- Kein Cloud-Dienst, keine Telemetrie, alle Daten bleiben lokal

# VoiceScribe

Lokale Sprach-Diktiersoftware für macOS als Menu-Bar-App.

- **Diktat-Modus**: Sprache → Whisper → Text direkt eingefügt
- **Überarbeitungs-Modus**: Sprache → Whisper → Ollama-KI verfeinert → Text eingefügt
- Vollständig offline nach dem ersten Modell-Download
- Kein Cloud-Dienst, keine Datenübertragung

---

## Voraussetzungen

| Anforderung | Version |
|---|---|
| macOS | **Sonoma 14.0** oder neuer |
| Xcode | 15 oder neuer (kostenlos im App Store) |
| Homebrew | Für XcodeGen-Installation |

> **Hinweis**: macOS Ventura 13 wird **nicht** unterstützt, da WhisperKit macOS 14 benötigt.

---

## Installation

### 1. Projekt einrichten

```bash
# In den VoiceScribe-Ordner wechseln
cd /Pfad/zu/VoiceScribe

# Setup-Skript ausführen (installiert XcodeGen + generiert Xcode-Projekt)
./setup.sh
```

### 2. In Xcode öffnen

```bash
open VoiceScribe.xcodeproj
```

### 3. Signing konfigurieren

In Xcode:
- Linke Sidebar → **VoiceScribe** (Projektdatei) klicken
- Tab **Signing & Capabilities** öffnen
- **Team**: Eigenen Apple-Account wählen (kostenloser Account reicht für lokales Testen)

### 4. Bauen und starten

**Cmd+R** in Xcode — Die App startet und erscheint als Icon in der Menüleiste.

### 5. Berechtigungen erteilen

Beim ersten Start erscheinen zwei Berechtigungsanfragen:

**Mikrofon**: Beim ersten Drücken des Tastenkürzel → „Erlauben" klicken.

**Bedienungshilfen** (für Text-Einfügen):
1. Systemeinstellungen öffnen
2. **Datenschutz & Sicherheit** → **Bedienungshilfen**
3. **VoiceScribe** in der Liste aktivieren

Alternativ: In VoiceScribe-Einstellungen (⌘,) → Tab „Modelle" → „Erlauben…"-Button.

---

## Ollama einrichten (Überarbeitungs-Modus)

Der Überarbeitungs-Modus ist optional. Ohne Ollama funktioniert der Diktat-Modus vollständig.

```bash
# Ollama installieren
brew install ollama

# Ollama-Dienst starten (läuft im Hintergrund)
ollama serve &

# Deutsches Sprachmodell herunterladen (~4 GB)
ollama pull mistral

# Alternativ: kleineres Modell
ollama pull llama3.2:3b
```

Ollama läuft danach automatisch unter `http://localhost:11434`.  
VoiceScribe verbindet sich beim Start automatisch.

---

## Verwendung

### Tastenkürzel

| Aktion | Standard-Kürzel |
|---|---|
| Aufnahme starten/stoppen | **⌥Space** (Option + Leertaste) |
| Einstellungen öffnen | **⌘,** (im Menü) |

Das Tastenkürzel ist in den Einstellungen frei konfigurierbar.

### Ablauf

1. Cursor in ein Textfeld setzen (z. B. in TextEdit, VS Code, Browser)
2. **⌥Space** drücken → kleines Panel erscheint oben im Bildschirm
3. Sprechen
4. **⌥Space** nochmals drücken → Aufnahme stoppt, Text wird transkribiert
5. Text erscheint automatisch an der Cursor-Position

### Modus wechseln

Im Menüleisten-Icon klicken → **Diktat** oder **Überarbeiten** auswählen.

Oder: Einstellungen (⌘,) → Tab „Allgemein".

---

## Einstellungen

| Einstellung | Beschreibung |
|---|---|
| Tastenkürzel | Globales Hotkey für Aufnahme |
| Modus | Diktat (direkt) oder Überarbeiten (mit KI) |
| Sprache | Deutsch / Englisch / Auto-Erkennung usw. |
| Whisper-Modell | Tiny (schnell) bis Medium (genau) |
| Ollama-Modell | Auswahl aus installierten lokalen Modellen |

---

## Whisper-Modelle

| Modell | Größe | Geschwindigkeit | Qualität |
|---|---|---|---|
| Tiny | ~150 MB | sehr schnell | ausreichend |
| Base | ~300 MB | schnell | gut |
| Small | ~500 MB | mittel | **empfohlen** |
| Medium | ~1,5 GB | langsam | sehr gut |

Das Modell wird beim ersten Transkribieren automatisch heruntergeladen.  
Gespeichert in: `~/Library/Caches/com.stefanwiggeshoff.VoiceScribe/`

---

## Fehlerbehebung

### Text wird nicht eingefügt
→ Bedienungshilfen-Berechtigung prüfen (Systemeinstellungen → Datenschutz → Bedienungshilfen)

### „Ollama läuft nicht"
→ Terminal: `ollama serve` ausführen

### Whisper-Modell lädt nicht
→ Internetverbindung beim ersten Start erforderlich. Danach vollständig offline.

### Kein Mikrofon-Zugriff
→ Systemeinstellungen → Datenschutz → Mikrofon → VoiceScribe aktivieren

### App erscheint nicht in der Menüleiste
→ Im Finder: `~/Applications/VoiceScribe.app` öffnen. Beim Build aus Xcode: App läuft im Debug-Ordner.

---

## Deinstallation

1. VoiceScribe beenden (Menüleiste → „VoiceScribe beenden")
2. `VoiceScribe.app` in den Papierkorb
3. Optional: Caches löschen: `rm -rf ~/Library/Caches/com.stefanwiggeshoff.VoiceScribe`
4. Optional: Einstellungen löschen: `defaults delete com.stefanwiggeshoff.VoiceScribe`

---

## Technologie

- **Swift 5.9** / **SwiftUI** / **AppKit**
- **WhisperKit** — lokale Spracherkennung via Apple Neural Engine (Core ML)
- **Ollama** — lokaler LLM-Dienst (Mistral, LLaMA, etc.)
- **AVFoundation** — Mikrofon-Aufnahme
- **KeyboardShortcuts** — globale Tastenkürzel
- Kein Cloud-Dienst, keine Telemetrie, alle Daten bleiben lokal

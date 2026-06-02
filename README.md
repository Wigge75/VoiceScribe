# VoiceScribe

Lokale Sprach-Diktiersoftware für macOS als Menu-Bar-App.

- **Diktat-Modus**: Sprache → Whisper → Text in Zwischenablage
- **Überarbeitungs-Modus**: Sprache → Whisper → Apple Intelligence verfeinert → Text in Zwischenablage
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

**Mikrofon**: Wird einmalig beim ersten Drücken des Tastenkürzel angefragt. Keine weiteren Berechtigungen nötig.

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
1. **⌥Space** drücken → Panel erscheint, Aufnahme-Timer startet
2. Sprechen — ein kurzer Ton bestätigt den Start
3. Aufnahme stoppt automatisch nach Stille — oder **⌥Space** nochmals drücken (Stopp-Ton)
4. Text landet sofort in der Zwischenablage, Panel schließt sich nach 1 Sek.

**Überarbeitung:**
1. **⌥Space** drücken → Panel erscheint, Aufnahme-Timer startet
2. Sprechen — ein kurzer Ton bestätigt den Start
3. Aufnahme stoppt automatisch nach Stille — oder **⌥Space** nochmals drücken (Stopp-Ton)
4. Apple Intelligence überarbeitet den Text im gewählten Stil
5. Text landet automatisch in der Zwischenablage, Panel schließt sich nach 1,5 Sek.

### Auto-Stopp nach Stille

Die Aufnahme stoppt automatisch wenn du aufgehört hast zu sprechen. Die Stille-Dauer ist konfigurierbar (Aus / 1 / 1,5 / 2 / 3 / 5 Sek., Standard: 1,5 Sek.).

Kurze Umgebungsgeräusche (Stuhlknarzen, Tippen) unterbrechen den Timer nicht.

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

### Persönliche Stilbeispiele (Few-Shot Prompting)

VoiceScribe kann deinen persönlichen Schreibstil lernen — ohne Cloud, ohne Training.

**So funktioniert es:**
- Überarbeitete Texte als Stilreferenz speichern → die KI orientiert sich beim nächsten Mal daran
- Bis zu 5 Beispiele pro Stil fließen automatisch in den Prompt ein

**Beispiele verwalten:**

| Aktion | Weg |
|---|---|
| Manuell eingeben | Einstellungen (⌘,) → **Stile** → **+** beim gewünschten Stil |
| Bearbeiten | Einstellungen → Stile → **✏️** neben dem Beispiel |
| Löschen | Einstellungen → Stile → **🗑** neben dem Beispiel |

---

## Einstellungen

| Einstellung | Beschreibung |
|---|---|
| Tastenkürzel | Globales Hotkey für Aufnahme + Stil/Modus-Shortcuts |
| Modus | Diktat oder Überarbeiten |
| Standard-Stil | Beruflich / Locker / Mit Emojis |
| Auto-Stopp | Stille-Dauer für automatisches Aufnahme-Ende |
| Sprache | Deutsch / Englisch / Auto-Erkennung usw. |
| Whisper-Modell | Tiny (schnell) bis Medium (genau) |
| Stile | Persönliche Stilbeispiele hinzufügen, bearbeiten und löschen |

---

## Whisper-Modelle

| Modell | Größe | Empfehlung |
|---|---|---|
| Tiny | ~150 MB | Sehr schnell, ausreichend für einfache Texte |
| Base | ~300 MB | Gute Balance aus Geschwindigkeit und Qualität |
| Small | ~500 MB | Empfohlen für normale Nutzung |
| Medium | ~1,5 GB | Beste Qualität, langsamer |

Das Modell wird beim ersten Start automatisch heruntergeladen (Internetverbindung nötig).  
Den Fortschritt siehst du in **Einstellungen → Modelle**:
- **Lädt herunter… X%** — einmaliger Download (~300 MB)
- **Modell wird kompiliert…** — einmalige CoreML-Spezialisierung für deinen Chip (~2 Min.)

Danach vollständig offline. Ab der zweiten Transkription ist alles deutlich schneller.

---

## Fehlerbehebung

### „KI nicht verfügbar"
→ Apple Intelligence ist nicht aktiviert: **Systemeinstellungen → Apple Intelligence → aktivieren**  
→ Oder: Dein Gerät ist nicht kompatibel (Intel-Mac oder Apple Silicon vor M1)

### Whisper-Modell lädt nicht
→ Internetverbindung beim ersten Start erforderlich. Danach vollständig offline.  
→ Fortschritt in **Einstellungen (⌘,) → Tab „Modelle"** sichtbar.

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

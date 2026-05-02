#!/usr/bin/env bash
# setup.sh — Einmalige Einrichtung von VoiceScribe
# Installiert XcodeGen (falls nötig) und generiert das Xcode-Projekt.

set -euo pipefail

echo "╔══════════════════════════════════════╗"
echo "║       VoiceScribe Setup              ║"
echo "╚══════════════════════════════════════╝"
echo ""

# 1. Homebrew prüfen
if ! command -v brew &>/dev/null; then
    echo "❌  Homebrew nicht gefunden."
    echo "    Installiere Homebrew von https://brew.sh und starte setup.sh erneut."
    exit 1
fi
echo "✅  Homebrew gefunden"

# 2. Xcode Command Line Tools prüfen
if ! xcode-select -p &>/dev/null; then
    echo "⚙️   Installiere Xcode Command Line Tools..."
    xcode-select --install
    echo ""
    echo "⚠️   Bitte warte bis die Installation abgeschlossen ist,"
    echo "    dann starte setup.sh erneut."
    exit 1
fi
echo "✅  Xcode Command Line Tools gefunden"

# 3. XcodeGen installieren (falls nötig)
if ! command -v xcodegen &>/dev/null; then
    echo "⚙️   Installiere XcodeGen..."
    brew install xcodegen
else
    echo "✅  XcodeGen gefunden ($(xcodegen --version 2>/dev/null | head -1))"
fi

# 4. Xcode-Projekt generieren
echo ""
echo "⚙️   Generiere VoiceScribe.xcodeproj..."
xcodegen generate

echo ""
echo "╔══════════════════════════════════════╗"
echo "║       Setup abgeschlossen! ✅         ║"
echo "╚══════════════════════════════════════╝"
echo ""
echo "Nächste Schritte:"
echo ""
echo "  1. VoiceScribe.xcodeproj in Xcode öffnen:"
echo "     open VoiceScribe.xcodeproj"
echo ""
echo "  2. In Xcode: Signing & Capabilities → Team setzen"
echo "     (eigenen Apple-Account oder 'None' für lokales Testen)"
echo ""
echo "  3. Bauen & Starten: Cmd+R"
echo ""
echo "  4. Beim ersten Start: Mikrofon-Zugriff erlauben"
echo ""
echo "  5. In Systemeinstellungen > Datenschutz > Bedienungshilfen:"
echo "     VoiceScribe erlauben (für Text-Einfügen nötig)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Optional: Ollama für Überarbeitungs-Modus:"
echo ""
echo "  brew install ollama"
echo "  ollama serve &"
echo "  ollama pull mistral"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

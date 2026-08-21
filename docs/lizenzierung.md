# VoiKoo — Lizenzierung & Kommerzialisierung

Diese Datei dokumentiert den Stand der Überlegungen zur Lizenzierung und
zum kommerziellen Verkauf von VoiKoo. Hintergrund: VoiKoo soll
von einem privaten Projekt zu einem echten, verkauften Produkt werden
(z. B. einmaliger Download-Kauf, Beispielpreis 6 €, noch nicht final).

**Kein Vertragsdokument hier ist rechtlich geprüft.** Alles unten ist ein
Arbeitsentwurf. Vor dem ersten echten Verkauf sollte ein Anwalt/eine
Anwältin die LICENSE und die EULA gegenlesen — insbesondere wegen
deutschem Verbraucherrecht (Widerrufsrecht bei digitalen Gütern).

---

## 1. Status — was schon entschieden ist

- **Ziel:** VoiKoo kommerziell verkaufen, nicht mehr nur privates/Open-Source-Projekt.
- **Copyright:** Liegt automatisch bei Stefan Wiggeshoff, unabhängig von der gewählten Lizenz — Urheberschaft entsteht durch Schöpfung, nicht durch eine Lizenzdatei.
- **Aktuelle GitHub-`LICENSE` (MIT) ist ungeeignet fürs Verkaufsvorhaben:** MIT erlaubt jedem, den Code zu kopieren, zu verändern und sogar selbst zu verkaufen. Das widerspricht dem Ziel "mein Code, nichts wird verändert/weiterverkauft".
- **Wichtiger Fakt zur Historie:** Das Repo lief seit Mai 2026 öffentlich unter MIT-Lizenz. Wer den Code in dieser Zeit bereits geklont hat, hat die MIT-Rechte für *diese Kopie* rechtmäßig erhalten — das lässt sich nicht rückwirkend entziehen. Ein Lizenzwechsel gilt nur für den Code ab dem Zeitpunkt der Änderung.
- **§ 5 EULA (Widerrufsrecht bei digitalen Gütern):** Wird im Bestellprozess über eine aktive Checkbox gelöst ("Ich verzichte auf mein Widerrufsrecht, da ich sofortigen Zugriff auf den Download wünsche"). **Ohne diese aktive Bestätigung im Kaufprozess** besteht das 14-tägige Widerrufsrecht für Verbraucher in der EU unverändert fort — das reicht nicht, nur in der EULA zu erwähnen, es muss aktiv im Bestellprozess eingeholt werden.
- **Impressum:** Wird auf der Landingpage ergänzt — für eine deutsche Geschäftswebseite gesetzlich vorgeschrieben (§ 5 TMG), unabhängig vom Vertriebsweg.
- **§ 6 EULA (Updates):** Käufer bekommen **alle zukünftigen Updates inklusive** — keine kostenpflichtigen Sprünge auf neue Hauptversionen.

## 2. Noch offen — für die nächste Sitzung

- [ ] **Repo-Sichtbarkeit final festlegen:** Bleibt das GitHub-Repo öffentlich (mit der unten stehenden proprietären "Alle Rechte vorbehalten"-Lizenz statt MIT), oder wird es komplett auf privat gestellt? (Privat = niemand sieht den Code mehr, aber dann können GitHub Releases nicht mehr als öffentlicher Downloadweg dienen — bräuchte eigene Hosting-Lösung für die App.)
- [ ] **Vertriebsweg festlegen:** Mac App Store (Apple übernimmt Bezahlung/Lizenzprüfung, 99$/Jahr Dev-Account, App Review, 15–30 % Provision) vs. Direktverkauf über Zahlungsanbieter (z. B. Gumroad, Paddle, LemonSqueezy — kein Review, mehr Kontrolle) vs. andere Lösung.
- [ ] **Preis final festlegen** (aktuell nur Beispielwert "6 €" genannt, keine endgültige Entscheidung).
- [ ] **Platzhalter in der EULA ausfüllen:** Datum, App-Version, Anzahl Mac(s) pro Lizenz, Gerichtsstand, Kontakt-E-Mail-Adresse.
- [ ] **Falls Repo öffentlich bleibt:** Die echte `LICENSE`-Datei im Repo tatsächlich von MIT auf den proprietären Entwurf (siehe unten) umstellen und pushen — bisher nur als Entwurf vorbereitet, noch nicht angewendet.
- [ ] **Landingpage anpassen**, sobald das Lizenzmodell final steht: aktuell wirbt sie noch mit einem "Open Source"-Badge und verlinkt direkt auf GitHub-Releases zum Download — das passt nur zum "Repo bleibt öffentlich"-Szenario und muss ggf. raus/angepasst werden, falls das Repo privat wird.
- [ ] **Bestellprozess technisch umsetzen:** Checkbox-Text für den Widerrufsverzicht (§ 5) in den tatsächlichen Checkout-Flow einbauen, sobald der Vertriebsweg steht.

## 3. Kernunterscheidung (rechtliche Einordnung, keine Rechtsberatung)

Zwei komplett unterschiedliche Dokumente werden oft verwechselt:

| | Regelt was? | Für wen? |
|---|---|---|
| **GitHub-`LICENSE`** | Was darf mit dem **Quellcode** gemacht werden (kopieren, verändern, weiterverbreiten)? | Jeder, der das Repo sieht |
| **EULA** | Was darf ein **zahlender Kunde** mit der fertigen, kompilierten App machen? | Käufer der App |

Jede echte Open-Source-Lizenz (MIT, Apache, GPL, BSD …) räumt per Definition
genau die Rechte ein, die man bei "nichts darf verändert werden" nicht will —
kopieren, verändern, weiterverbreiten, auch kommerziell. Es gibt keine
Open-Source-Lizenz, die das verhindert — das ist ein Widerspruch in sich.

Optionen für den Quellcode:

| Option | Sichtbarkeit | Verändern/Weiterverbreiten erlaubt? |
|---|---|---|
| Kein LICENSE-File (Standard-Urheberrecht) | Öffentlich einsehbar | Nein — Standardrecht: "alle Rechte vorbehalten" |
| Proprietäre Lizenz / eigenes Copyright (siehe unten) | Öffentlich, mit expliziter Ansage | Nein, explizit ausformuliert |
| Source-available (z. B. PolyForm Noncommercial/Strict) | Öffentlich | Stark eingeschränkt, meist nur Ansehen/Testen |
| Repo privat | Niemand sieht den Code | Volle Kontrolle, aber kein öffentlicher Downloadweg über GitHub Releases |

## 4. LICENSE-Entwurf (ersetzt MIT — noch nicht ins Repo übernommen)

```text
Copyright © 2026 Stefan Wiggeshoff. Alle Rechte vorbehalten.
All rights reserved.

Dieser Quellcode wird ausschließlich zu Informations- und Transparenzzwecken
öffentlich einsehbar gemacht. Es wird keine Lizenz zur Nutzung, Vervielfältigung,
Veränderung, Zusammenführung, Veröffentlichung, Verbreitung, Unterlizenzierung
und/oder zum Verkauf von Kopien dieser Software erteilt.

Insbesondere ist Folgendes ohne vorherige ausdrückliche schriftliche Zustimmung
des Urhebers nicht gestattet:

  - das Kopieren, Verändern oder Erstellen abgeleiteter Werke des Quellcodes
  - die Kompilierung, Verbreitung oder Veröffentlichung eigener Builds der Software
  - der Weiterverkauf oder die kommerzielle Nutzung des Quellcodes oder daraus
    erzeugter Software
  - die Verwendung von Namen, Markenzeichen oder Designelementen von VoiKoo

Die fertige Anwendung ("VoiKoo") kann über die vom Urheber autorisierten
Vertriebswege (z. B. offizielle Downloadseite, App Store) bezogen werden; die
Nutzung der fertigen Anwendung durch Endnutzer unterliegt der separaten
Endnutzer-Lizenzvereinbarung (EULA).

DIE SOFTWARE WIRD OHNE MÄNGELGEWÄHR ("AS IS") BEREITGESTELLT, OHNE JEGLICHE
AUSDRÜCKLICHE ODER STILLSCHWEIGENDE GEWÄHRLEISTUNG, EINSCHLIESSLICH, ABER NICHT
BESCHRÄNKT AUF DIE GEWÄHRLEISTUNG DER MARKTGÄNGIGKEIT, DER EIGNUNG FÜR EINEN
BESTIMMTEN ZWECK UND DER NICHTVERLETZUNG VON RECHTEN DRITTER.

---

Copyright © 2026 Stefan Wiggeshoff. All rights reserved.

This source code is made publicly viewable for transparency purposes only.
No license is granted to use, copy, modify, merge, publish, distribute,
sublicense, and/or sell copies of this software.

Without prior express written permission from the copyright holder, you may
NOT:

  - copy, modify, or create derivative works of the source code
  - compile, distribute, or publish your own builds of the software
  - resell or commercially exploit the source code or any software derived
    from it
  - use the VoiKoo name, trademarks, or design assets

The compiled application ("VoiKoo") is available through the author's
authorized distribution channels (e.g. the official download page, App
Store); end-user use of the compiled application is governed by a separate
End User License Agreement (EULA).

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
```

## 5. EULA-Entwurf

```markdown
# Endnutzer-Lizenzvereinbarung (EULA) für VoiKoo

**ENTWURF — vor kommerziellem Einsatz von einem Anwalt/einer Anwältin prüfen lassen.**

Stand: [DATUM] · Version: [APP-VERSION]

## 1. Vertragspartner und Gegenstand

Diese Endnutzer-Lizenzvereinbarung ("EULA") gilt zwischen Stefan Wiggeshoff
("Lizenzgeber") und der Person oder Organisation, die VoiKoo erwirbt und
nutzt ("Lizenznehmer"). Sie regelt die Nutzung der Software "VoiKoo"
("Software") in kompilierter, lauffähiger Form. Mit dem Kauf, Download,
der Installation oder Nutzung der Software erklärt sich der Lizenznehmer mit
dieser EULA einverstanden.

## 2. Lizenzumfang

Der Lizenzgeber räumt dem Lizenznehmer gegen Zahlung des vereinbarten
Entgelts eine einfache (nicht ausschließliche), nicht übertragbare,
nicht unterlizenzierbare Lizenz zur Nutzung der Software auf [ANZAHL]
Mac(s) ein, die im Eigentum oder unter der Kontrolle des Lizenznehmers
stehen, ausschließlich zum eigenen Gebrauch.

## 3. Einschränkungen

Der Lizenznehmer darf die Software NICHT:

- dekompilieren, zurückentwickeln (Reverse Engineering) oder den
  Quellcode auf andere Weise zu extrahieren versuchen, außer soweit
  zwingendes Recht dies ausdrücklich erlaubt;
- verändern, davon abgeleitete Werke erstellen oder Sicherheits- bzw.
  Lizenzmechanismen umgehen;
- verkaufen, vermieten, verleasen, verleihen, unterlizenzieren oder
  anderweitig an Dritte weitergeben;
- für Dritte im Rahmen eines Dienstleistungs- oder SaaS-Angebots
  bereitstellen, ohne vorherige schriftliche Zustimmung des
  Lizenzgebers.

## 4. Eigentum und Rechte

Die Software sowie alle Rechte daran (einschließlich Urheberrechte,
Marken- und sonstige Schutzrechte) verbleiben beim Lizenzgeber. Diese
EULA räumt lediglich ein Nutzungsrecht ein, kein Eigentum an der
Software.

## 5. Preis, Zahlung und Widerrufsrecht

Der Kaufpreis beträgt [PREIS] für einen einmaligen Kauf. Bei
Verbrauchern in der EU besteht bei Fernabsatzverträgen grundsätzlich
ein 14-tägiges Widerrufsrecht. Dieses Widerrufsrecht **erlischt
vorzeitig**, wenn der Lizenznehmer der sofortigen Ausführung des
Vertrags ausdrücklich zustimmt UND seine Kenntnis vom Erlöschen des
Widerrufsrechts bei vollständiger Vertragserfüllung bestätigt (§ 356
Abs. 5 BGB, Art. 16 lit. m Verbraucherrechte-Richtlinie) —
**das wird im Bestellprozess aktiv per Checkbox eingeholt** (z. B.
"Ich verzichte auf mein Widerrufsrecht, da ich sofortigen Zugriff auf
den Download wünsche"), nicht nachträglich in dieser EULA. Ohne diese
aktive Bestätigung im Kaufprozess besteht das Widerrufsrecht
unverändert fort.

## 6. Updates

Der Kaufpreis deckt alle zukünftigen Updates von VoiKoo ab —
es gibt keine kostenpflichtigen Sprünge auf neue Hauptversionen.

## 7. Gewährleistung und Haftung

Die Software wird "wie besehen" bereitgestellt. Der Lizenzgeber
übernimmt keine Gewähr dafür, dass die Software fehlerfrei oder
ununterbrochen läuft. Die Haftung des Lizenzgebers ist auf Vorsatz und
grobe Fahrlässigkeit beschränkt, soweit gesetzlich zulässig; die
Haftung für Schäden aus der Verletzung des Lebens, des Körpers oder der
Gesundheit sowie nach dem Produkthaftungsgesetz bleibt unberührt.

## 8. Datenverarbeitung

VoiKoo verarbeitet Audiodaten und Text ausschließlich lokal auf
dem Gerät des Lizenznehmers (WhisperKit, Apple Intelligence). Es findet
keine Übertragung von Aufnahmen oder transkribierten Texten an Server
des Lizenzgebers statt. [FALLS DOCH TELEMETRIE/CRASH-REPORTS/LIZENZ-
PRÜFUNG STATTFINDET: hier ergänzen und eine Datenschutzerklärung
verlinken.]

## 9. Kündigung

Diese Lizenz erlischt automatisch bei Verstoß gegen diese EULA. Der
Lizenznehmer hat die Software in diesem Fall zu löschen.

## 10. Schlussbestimmungen

Es gilt das Recht der Bundesrepublik Deutschland unter Ausschluss des
UN-Kaufrechts. Gerichtsstand ist, soweit gesetzlich zulässig,
[GERICHTSSTAND]. Sollte eine Bestimmung dieser EULA unwirksam sein,
bleibt die Wirksamkeit der übrigen Bestimmungen unberührt.

Kontakt: [KONTAKT-E-MAIL]
```

## 6. Zugehörige Assets

- Landingpage-Entwurf (Claude Design): enthält aktuell noch ein "Open
  Source"-Badge und direkte GitHub-Release-Download-Links — muss
  überprüft werden, sobald Repo-Sichtbarkeit final entschieden ist.
- LICENSE-Entwurf und EULA-Entwurf liegen zusätzlich als einzelne
  Dateien im Scratchpad der Sitzung, in der sie erstellt wurden.

---

## 7. Prompt für die nächste Sitzung

Zum Weiterarbeiten diesen Prompt in einer neuen Sitzung eingeben:

```
Wir haben in einer früheren Sitzung die Lizenzierung und
Kommerzialisierung von VoiKoo besprochen und dokumentiert. Lies
bitte die Datei docs/lizenzierung.md im VoiKoo-Projekt
(ClaudeCode Projekte/VoiKoo) vollständig — dort stehen alle
bisherigen Entscheidungen, der LICENSE-Entwurf und der EULA-Entwurf.

Arbeite mit mir Abschnitt "2. Noch offen" durch, Punkt für Punkt:
Repo-Sichtbarkeit final festlegen, Vertriebsweg auswählen, Preis
festlegen, EULA-Platzhalter ausfüllen, LICENSE-Datei im Repo ggf.
tatsächlich ersetzen, Landingpage entsprechend anpassen, und den
Bestellprozess (inkl. Widerrufsverzicht-Checkbox aus § 5 der EULA)
konkret umsetzen.
```

# Security Policy

Die Sicherheit des Mitmachportals und der darauf verarbeiteten Daten hat
für uns hohe Priorität. Wir freuen uns über Hinweise von
Sicherheitsforschenden und Nutzer:innen, die uns helfen, die Plattform
sicherer zu machen.

## Meldung von Sicherheitslücken

Wenn Sie eine Sicherheitslücke im Mitmachportal entdecken, bitten wir Sie,
diese verantwortungsvoll und vertraulich zu melden, bevor Sie sie
öffentlich machen (Responsible Disclosure / koordinierte Offenlegung).

Bitte melden Sie Sicherheitslücken per E-Mail an:

**security@demokratie.today** <!-- PLATZHALTER - gewünschte Kontaktadresse eintragen -->

Bitte geben Sie in Ihrer Meldung nach Möglichkeit an:

- eine Beschreibung der Schwachstelle und ihrer potenziellen Auswirkung,
- Schritte zur Reproduktion (sofern zutreffend), idealerweise als
  nachvollziehbare Abfolge oder mit Screenshots,
- betroffene URL(s), Komponente(n) oder Version(en),
- Ihre Einschätzung des Schweregrads (sofern vorhanden),
- Ihre Kontaktdaten für Rückfragen.

Auch unvollständige Meldungen sind willkommen – melden Sie lieber früh als
gar nicht; wir klären offene Punkte gemeinsam mit Ihnen.

## Was Sie erwarten können

- Wir bestätigen den Eingang Ihrer Meldung innerhalb von **3 Werktagen**.
- Wir bewerten die Meldung, ordnen den Schweregrad ein und informieren Sie
  über das Ergebnis und den weiteren Bearbeitungsstand.
- Bestätigte Schwachstellen beheben wir priorisiert nach Schweregrad;
  kritische Lücken werden unverzüglich behandelt.
- Wir stimmen den Zeitpunkt einer etwaigen Veröffentlichung mit Ihnen ab
  und bitten um eine angemessene Frist zur Behebung, bevor Details
  öffentlich gemacht werden.
- Auf Wunsch nennen wir Sie nach Behebung der Schwachstelle namentlich als
  Melder:in; auf Wunsch behandeln wir Ihre Meldung vollständig anonym.

Wir betreiben derzeit kein Bug-Bounty-Programm; es besteht kein Anspruch
auf eine Vergütung.

## Umfang (Scope)

Diese Policy bezieht sich auf:

- die Software des Mitmachportals (dieses Repository) und
- die von demokratie.today betriebenen Instanzen.

**Nicht in den Umfang fallen:**

- Systeme und Dienste Dritter, die von der Plattform lediglich eingebunden
  werden (z. B. Kartendienste, E-Mail-Versanddienste, staatliche
  Anmeldedienste wie BundID/BayernID) — bitte melden Sie Schwachstellen
  dort direkt beim jeweiligen Anbieter,
- Schwachstellen in Abhängigkeiten ohne konkret nachvollziehbare
  Auswirkung auf das Mitmachportal (reine Versionshinweise aus Scannern),
- fehlende Härtungsmaßnahmen ohne demonstrierbares Risiko (z. B. einzelne
  fehlende HTTP-Header ohne ausnutzbare Auswirkung),
- Social Engineering, Phishing gegen Mitarbeitende oder Nutzer:innen sowie
  physische Angriffe.

Bitte führen Sie **keine Tests durch, die den Betrieb der Plattform oder
die Daten Dritter beeinträchtigen könnten** — insbesondere keine
Lasttests oder Denial-of-Service-Tests, keine automatisierten
Massenabfragen und keinen Zugriff auf personenbezogene Daten anderer
Nutzer:innen. Sollten Sie beim Nachweis einer Schwachstelle unbeabsichtigt
auf fremde Daten stoßen, brechen Sie den Test ab, speichern Sie die Daten
nicht und teilen Sie uns dies in Ihrer Meldung mit.

## Safe Harbor

Meldungen, die in gutem Glauben und im Rahmen dieser Policy erfolgen,
werden von uns nicht rechtlich verfolgt. Das setzt voraus, dass Sie

- nur so weit testen, wie es für den Nachweis der Schwachstelle
  erforderlich ist,
- keine Daten Dritter einsehen, verändern, löschen oder weitergeben,
- die Verfügbarkeit der Plattform nicht beeinträchtigen und
- die Schwachstelle vertraulich behandeln, bis sie behoben ist.

Vielen Dank, dass Sie zur Sicherheit des Mitmachportals beitragen.

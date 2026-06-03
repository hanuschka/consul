# Design: Moderne Flash-/Toast-Benachrichtigungen

**Datum:** 2026-05-26
**Branch:** new-connection
**Scope:** Umgestaltung der Flash-Benachrichtigungen ("Flyins") des öffentlichen Frontends
zu modernen, barrierefreien, mobil-tauglichen Toasts. Behebt zugleich den
horizontalen Überlauf auf Mobilgeräten.

---

## 1. Problem

Die aktuellen Flash-Meldungen sind klassische Foundation-Callouts und wirken veraltet:
blass, flach, ohne Icon, mit überdimensioniertem `×` (35px). Zwei konkrete Mängel:

1. **Optik veraltet** – passt nicht zum modernen Civic-Design-Token-System
   (`app/assets/stylesheets/custom_new_design/_civic_design.scss`).
2. **Mobiler Überlauf (Bug):** Die Einblend-Animation startet bei
   `transform: translate3d(100%, 0, 0)` (`app/assets/stylesheets/layout.scss:1172-1181`).
   Das Element wird um 100 % seiner Breite nach rechts aus dem Viewport geschoben.
   Da nirgends `overflow-x: hidden` greift, **verbreitert sich während der 1-s-Animation
   die ganze Seite** → horizontales Scrollen/„Verrutschen" auf dem Handy.
   Sekundär: `min-width: $line-height * 12` (~288px, `layout.scss:1184`) kann sehr
   schmale Viewports sprengen.

## 2. Betroffene Dateien (Ist-Zustand)

| Datei | Rolle |
|---|---|
| `app/views/custom/layouts/_flash.html.erb` | Markup (überschreibt Basis); rendert **leeren** `.notice-text` + `data-flash-text`, Text wird per JS injiziert |
| `app/views/layouts/_flash.html.erb` | Basis-Partial (rendert Text inline) – wird durch das custom-Partial global überschrieben |
| `app/assets/javascripts/custom/flash_messages.js` | injiziert Text, befüllt SR-Live-Region, setzt Fokus |
| `app/assets/javascripts/custom/init.js:49` | ruft `App.FlashMessages.initialize()` (via `turbolinks:load`, `application.js:245`) |
| `app/assets/stylesheets/layout.scss:1166-1238` | Slide-Keyframes, `.notice-container`, `.callout`-Farben |
| `app/assets/stylesheets/custom/shared_v2.scss:5-38` | Radius, `.close-button`, `.notice-text` |
| `app/assets/stylesheets/custom_new_design/_base.scss:49-90` | Positionierung + Header-Offsets |

**Wichtige Randbedingung:** Das `custom`-Partial und `flash_messages.js` (Teil von
`application.js`) werden in **allen** Kontexten geladen (öffentlich, Admin, Management,
Devise). Änderungen dürfen diese Kontexte nicht regressieren. → siehe §8.

## 3. Ziele

- Moderne Toast-Optik passend zu den Civic-Tokens.
- **Auto-Dismiss** nach 5 s für `success`/`notice`/`info`; `alert`/`error`/`warning`
  bleiben bis manuellem Schließen.
- Mehrere Meldungen **stapeln** sauber.
- **Mobil:** oben angedockt, volle Restbreite, **kein** horizontaler Überlauf.
- **Barrierefrei:** korrekte Live-Regions, kein Fokus-Diebstahl, Tastaturbedienung,
  `prefers-reduced-motion`, Kontrast ≥ 4.5:1.

## 4. Gewählte Umsetzung (Variante A)

Bestehendes Server-Rendering beibehalten, aber:
- `custom/_flash.html.erb` neu strukturieren (Stack-Wrapper, Typ-Icon, Text **inline**).
- Gesamtes Styling in **einer** neuen Partial `custom_new_design/_toasts.scss` bündeln;
  alte verstreute Regeln entfernen/ersetzen.
- `flash_messages.js` um Auto-Dismiss, animiertes Ausblenden, Pause-bei-Hover und
  saubere Live-Region-Logik erweitern.

Verworfen: **B** (ViewComponent – mehr Aufwand, Partial genügt) und
**C** (Stimulus-Toast-Manager – größter Umbau, Frontend nutzt jquery-ujs, nicht Stimulus).

## 5. Visuelles Design

Weiße Karte mit farbiger Akzent-Leiste links (4px) + farbigem Icon + dunklem Text.
Garantiert Kontrast und passt zum Civic-Design (weiße Cards, weiche Schatten).

```
┌─────────────────────────────────────────┐
┃ ✓   Sie haben sich erfolgreich        × ┃   ← farbige Leiste links + Icon
┃     angemeldet.                          ┃
└─────────────────────────────────────────┘
```

- **Karte:** `background: #FFFFFF`, `border-radius: 8px`,
  `box-shadow: 0 8px 24px rgba(0,0,0,.12)`, `padding: 14px 16px`,
  `border-left: 4px solid <typfarbe>`.
- **Text:** `color: #0F172A`, `font-family: 'Source Sans 3', sans-serif`, `font-size: 16px`,
  `line-height: 1.45`. Icon und `×` flex-ausgerichtet.
- **Icon:** Font Awesome (bereits im Projekt), `aria-hidden="true"`, in Typfarbe.
- **Close-Button:** `×`, Trefferfläche **≥ 44×44px**, `aria-label` (i18n `application.close`),
  sichtbarer `:focus-visible`-Ring.

### Typ-Zuordnung

| Flash-Key | Akzentfarbe | FA-Icon | Verhalten | Live-Region |
|---|---|---|---|---|
| `success`, `notice` | `#16A34A` (grün) | `fa-circle-check` | auto-dismiss 5 s | polite |
| `info` | `#0369A1` (blau) | `fa-circle-info` | auto-dismiss 5 s | polite |
| `warning` | `#B45309` (amber) | `fa-triangle-exclamation` | bleibt | assertive |
| `alert`, `error` | `#DC2626` (rot) | `fa-circle-exclamation` | bleibt | assertive |

Alle Kontrastpaare (Akzentfarbe + Icon auf Weiß, Text `#0F172A` auf Weiß) erfüllen ≥ 4.5:1.
Der Allowlist-Filter im Partial wird auf `[:notice, :alert, :success, :error, :warning, :info]`
erweitert.

## 6. Position, Stacking & Mobile

- **Container** (`.toast-stack`): `position: fixed`, Flex-Spalte, `gap: 12px`,
  `z-index` aus der bestehenden Z-Index-Skala (über dem Header).
- **Desktop:** oben-rechts; Top-Offset übernimmt die bestehende Header-Logik aus
  `_base.scss` (inkl. Admin-Topbar-Varianten); `max-width: 380px`, `right: 20px`.
- **Mobil (≤ 640px):** `left: 12px; right: 12px`, Toasts volle Restbreite,
  **kein** `min-width`. Top-Offset zzgl. `env(safe-area-inset-top)` für Notch-Geräte.
- **Kein horizontaler Überlauf:** Animation nutzt ausschließlich `translateY`/`opacity`
  (kein Off-Screen-`translateX`). Zusätzlich `overflow-x` am Container neutral.

## 7. Animation (behebt den Bug)

- **Rein:** `opacity: 0; translateY(-12px)` → `opacity: 1; translateY(0)`, **220 ms ease-out**.
- **Raus:** `opacity → 0; translateY(-8px)`, **150 ms ease-in** (kürzer als rein).
- Nur `transform`/`opacity` → kein Reflow, keine CLS, keine Seitenverbreiterung.
- `@media (prefers-reduced-motion: reduce)`: nur Opacity-Fade, **kein** Transform.

## 8. Verhalten & JavaScript (`flash_messages.js`)

- **Auto-Dismiss:** Timer 5000 ms für `success`/`notice`/`info` (aus `data-flash-type`
  bzw. Typklasse). `alert`/`error`/`warning` bekommen **keinen** Timer.
- **Pause:** `mouseenter`/`focusin` auf dem Toast pausiert den Timer, `mouseleave`/`focusout`
  startet ihn neu.
- **Schließen:** Klick auf `.toast__close` blendet animiert aus und entfernt das Element
  aus dem DOM (eigene Logik statt Foundation `data-closable`).
- **Tastatur:** `Esc` schließt den fokussierten Toast.
- **Robustheit:** Text wird künftig **direkt im Partial** gerendert (sichtbar), nicht erst
  per JS. Fällt JS aus, bleibt die Meldung lesbar (keine leeren Toasts) – schützt
  insbesondere Admin/Management/Devise.

## 9. Barrierefreiheit (A11y)

- **Live-Regions:** zwei SR-only Regionen im DOM (bei Load vorhanden):
  `aria-live="polite"` und `role="alert"` (assertive). JS spiegelt den Toast-Text
  je nach Typ in die passende Region → zuverlässige Ansage.
- **Kein Fokus-Diebstahl:** Der bisherige Auto-Fokus auf den Meldungstext
  (`flash_messages.js` `FOCUS_DELAY`) wird **entfernt** (Verstoß gegen
  „Toasts must not steal focus"); Ansage erfolgt über die Live-Region.
- Der sichtbare Toast ist selbst **keine** Live-Region (vermeidet Doppel-Ansage),
  Text bleibt aber als statischer Inhalt für SR lesbar.
- Icon `aria-hidden="true"`; `×`-Button mit `aria-label`, ≥ 44×44px, `:focus-visible`-Ring.
- Information nie nur über Farbe: Icon + Text tragen die Bedeutung mit.

## 10. Aufräumen

Entfernen/ersetzen und in `custom_new_design/_toasts.scss` konsolidieren:
- `layout.scss:1166-1199` (`.callout-slide`, `@keyframes slide`, `.notice-container`)
- `custom/shared_v2.scss:5-38` (`.notice-text`, `.callout`-Override)
- `custom_new_design/_base.scss:49-90` (Positionierung – Header-Offsets übernehmen)

Die Callout-Farbregeln in `layout.scss:1201-1238` bleiben unangetastet, falls andere
Komponenten `.callout` außerhalb der Toasts verwenden (vor dem Entfernen prüfen).

## 11. Verifikation

- Manuell auf **375px** und **640px** Breite: kein horizontaler Scroll, Toast oben volle Breite.
- Jeder Typ (success/notice/info/warning/alert/error): Farbe, Icon, Auto-Dismiss vs. bleibend.
- `prefers-reduced-motion: reduce` aktiv: nur Fade.
- Tastatur: `Tab` zum `×`, `Enter`/`Space` schließt, `Esc` schließt; Fokusring sichtbar.
- Screenreader: success → höflich, error → sofort angesagt; kein Fokussprung beim Laden.
- **Regression:** Flash-Meldungen in **Admin, Management, Devise** rendern korrekt
  (Text sichtbar, schließbar) – kein leerer Toast.
- Mehrere gleichzeitige Flashes stapeln mit Abstand.

## 12. Offene Punkte / Risiken

- Genaue Top-Offsets bei `position: fixed` ggf. pro Layout nachjustieren (Header-Höhe).
- Prüfen, ob `.callout` außerhalb der Toasts genutzt wird, bevor Basisregeln entfernt werden.
- Bestätigen, dass Font-Awesome-Icon-Klassen in allen Kontexten verfügbar sind.

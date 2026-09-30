// Eye/calendar controls and the editor-only visibility hint of a content
// block. Rendered by `addStudioControlsToContentBlock` and re-rendered by
// `App.Studio.ContentBlocks.Visibility` after every save. Times arrive as
// German local "YYYY-MM-DDTHH:MM" strings, so no time zone math happens here.
App.Studio.Projekt.templateFunctions.formatVisibilityTime = function(value) {
  const [date, time] = value.split("T");
  const [year, month, day] = date.split("-");

  return `${day}.${month}.${year}, ${time} Uhr`;
};

App.Studio.Projekt.templateFunctions.visibilityPeriodText = function({ visibleFrom, visibleUntil }) {
  const format = App.Studio.Projekt.templateFunctions.formatVisibilityTime;

  if (visibleFrom && visibleUntil) return `${format(visibleFrom)} – ${format(visibleUntil)}`;
  if (visibleFrom) return `ab ${format(visibleFrom)}`;
  if (visibleUntil) return `bis ${format(visibleUntil)}`;

  return "";
};

App.Studio.Projekt.templateFunctions.visibilityToggleTooltips = {
  visible: {
    title: "Sichtbar",
    text: "Besucher*innen sehen diesen Block. Klicken, um ihn auszublenden."
  },
  hidden: {
    title: "Ausgeblendet",
    text: "Besucher*innen sehen diesen Block nicht, unabhängig vom Zeitraum. Klicken, um ihn wieder einzublenden."
  }
};

App.Studio.Projekt.templateFunctions.contentBlockVisibilityControlsHtml = function(visibility) {
  const tooltip = App.Studio.Projekt.templateFunctions.studioControlTooltip;
  const periodText = App.Studio.Projekt.templateFunctions.visibilityPeriodText(visibility);
  const toggleTooltips = App.Studio.Projekt.templateFunctions.visibilityToggleTooltips;
  const toggleTooltip = visibility.visible ? toggleTooltips.visible : toggleTooltips.hidden;

  return `
    <div class="custom-content-block-visibility-controls js-content-block-visibility-controls">
      ${tooltip(`
        <button
          type="button"
          tabindex="-1"
          class="studio-icon-button js-content-block-toggle-visibility${visibility.visible ? "" : " -visibility-off"}"
          aria-pressed="${visibility.visible}"
          aria-label="Für Besucher*innen sichtbar"
        >
          <i class="fas ${visibility.visible ? "fa-eye" : "fa-eye-slash"}"></i>
        </button>
      `, {
        delay: 1000,
        title: toggleTooltip.title,
        text: toggleTooltip.text
      })}
      ${tooltip(`
        <inline-popup
          class="js-content-block-visibility-period-popup"
          template-id="content-block-visibility-period-popup-template"
          body-class="content-block-visibility-period-popup"
          placement="bottom"
          align="end"
        >
          <button
            type="button"
            tabindex="-1"
            class="studio-icon-button js-content-block-edit-visibility-period${periodText ? " -active" : ""}"
            aria-label="Sichtbarkeitszeitraum festlegen"
          >
            <i class="fas fa-calendar-alt"></i>
          </button>
        </inline-popup>
      `, {
        delay: 1000,
        title: "Sichtbarkeitszeitraum",
        text: "Legt fest, von wann bis wann Besucher*innen diesen Block sehen. Alle Zeiten in deutscher Ortszeit.",
        note: periodText ? `Zeitraum: ${periodText}` : null
      })}
    </div>
  `;
};

// The label on the top edge of blocks citizens can't see. It is editor-only:
// preview-as-user drops those blocks entirely, and a visible block with a
// period hides its label there.
App.Studio.Projekt.templateFunctions.contentBlockVisibilityHintHtml = function(visibility) {
  const periodText = App.Studio.Projekt.templateFunctions.visibilityPeriodText(visibility);
  const tooltip = App.Studio.Projekt.templateFunctions.studioControlTooltip;
  const hints = {
    hidden: {
      icon: "fa-eye-slash",
      title: "Ausgeblendet",
      text: "Besucher*innen sehen diesen Block nicht, unabhängig vom Zeitraum. Über das Auge in der Symbolleiste blenden Sie ihn wieder ein."
    },
    scheduled: {
      icon: "fa-clock",
      title: "Noch nicht sichtbar",
      text: "Besucher*innen sehen diesen Block erst ab dem Beginn des Sichtbarkeitszeitraums."
    },
    expired: {
      icon: "fa-calendar-times",
      title: "Nicht mehr sichtbar",
      text: "Der Sichtbarkeitszeitraum ist abgelaufen, Besucher*innen sehen diesen Block nicht mehr."
    },
    visible: {
      icon: "fa-calendar-alt",
      title: "Sichtbar",
      text: "Besucher*innen sehen diesen Block nur innerhalb des angegebenen Zeitraums."
    }
  };
  const hint = hints[visibility.status] || hints.visible;
  const isVisible = visibility.status === "visible";
  let periodHtml = "";

  if (isVisible && !periodText) {
    return '<div class="content-block-visibility-hint js-content-block-visibility-hint" hidden></div>';
  }

  if (periodText) {
    periodHtml = `<span class="content-block-visibility-hint--period">· ${periodText}</span>`;
  }

  return `
    <div
      class="content-block-visibility-hint js-content-block-visibility-hint -${visibility.status}${isVisible ? " js-studio-hide-on-preview" : ""}"
      role="note"
    >
      ${tooltip(
        `<i class="fas ${hint.icon} content-block-visibility-hint--icon" aria-hidden="true"></i>`,
        { title: hint.title, text: hint.text, delay: 300 }
      )}
      <strong class="content-block-visibility-hint--title">${hint.title}</strong>
      ${periodHtml}
    </div>
  `;
};

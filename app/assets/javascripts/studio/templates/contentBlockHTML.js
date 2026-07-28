const html = (strings, ...values) => {
  return String.raw(strings, ...values);
};

App.Studio.Projekt.templateFunctions.emptyContentBlockHtml = '<div><p></p></div>';

// Wraps a studio control (button or control group) in a <rich-tooltip>
// (app/assets/javascripts/elements/rich_tooltip.js) with a title + explanation
// body. Declarative only — no extra tooltip JS. `delay` is the show delay in ms.
App.Studio.Projekt.templateFunctions.studioControlTooltip = function(triggerHtml, { title, text, note, delay, placement } = {}) {
  const delayAttribute = delay ? ` delay="${delay}"` : "";
  const placementAttribute = placement ? ` placement="${placement}"` : "";
  const titleHtml = title ? `<span class="rich-tooltip-content--title">${title}</span>` : "";
  const textHtml = text ? `<span class="rich-tooltip-content--text">${text}</span>` : "";
  const noteHtml = note ? `<span class="rich-tooltip-content--note">${note}</span>` : "";
  const focusableAttribute = note ? " focusable" : "";

  return `
    <rich-tooltip${delayAttribute}${placementAttribute} trigger-only${focusableAttribute}>
      ${triggerHtml}
      <template>
        <div class="rich-tooltip-content">
          ${titleHtml}
          ${textHtml}
          ${noteHtml}
        </div>
      </template>
    </rich-tooltip>
  `;
};

// Tooltip note shown when AI is not enabled — mirrors Shared::AiFeatureTooltipComponent.
App.Studio.Projekt.templateFunctions.aiDisabledTooltipNote =
  '<span class="ai-feature-tooltip--note-heading">KI aktivieren, um die Funktion zu nutzen</span> Wenden Sie sich an info@demokratie.today, um die KI-Funktion zu aktivieren.';

// Admin-only placeholder shown inside an empty projekt content block (studio
// only, hidden in preview-as-user). Mirrors the site-block hint rendered by
// `wrap_with_admin_empty_hint`; reuses the same `.content-block-empty-hint`
// markup/CSS. Visibility is driven by the `is-content-empty` marker on the
// wrapper, toggled live by `App.Studio.ContentBlocks.EmptyHintToggle`.
App.Studio.Projekt.templateFunctions.contentBlockEmptyHintHtml = function() {
  return `
    <div class="content-block-empty-hint js-content-block-empty-hint js-studio-hide-on-preview" role="note">
      <span class="content-block-empty-hint--icon" aria-hidden="true"><i class="fas fa-circle-info"></i></span>
      <span class="content-block-empty-hint--text">
        <strong class="content-block-empty-hint--title">Leerer Inhaltsblock</strong>
        <span class="content-block-empty-hint--description">Nur Sie (Admins &amp; Manager*innen) sehen diesen Hinweis. Bewegen Sie den Mauszeiger über den Block und klicken Sie auf die Symbolleiste, um Inhalte hinzuzufügen — der Block bleibt für Besucher*innen verborgen, bis er Inhalt enthält.</span>
      </span>
    </div>
  `;
};

App.Studio.Projekt.templateFunctions.wrapWithContentBlockListHtml = function(contentBlocks, projektId) {
  return `
    <div
      data-sort-url="/projekts/${projektId}/content_blocks/sort"
      data-template-section="projekt_page"
      class="js-content-blocks-list content-blocks-container"
    >
      <div
        class="add-new-content-block-section js-show-content-block-templates-section js-add-content-block-at-top -at-top js-studio-hide-on-preview"
        style="display: ${contentBlocks.length <= 0 ? 'none' : ''}"
      >
        <div class="add-new-content-block-section--controls">
          ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
            <button
              type="button"
              class="add-new-content-block-floating-control add-new-content-block-blank-button js-add-blank-content-block"
              tabindex="-1"
            >
              <i class="far fa-file"></i>
            </button>
          `, {
            title: "Leeren Inhaltsblock am Anfang hinzufügen",
            text: "Fügt ganz oben auf der Seite einen leeren Inhaltsblock hinzu, den Sie selbst gestalten.",
            delay: 1500
          })}
          ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
            <button
              type="button"
              class="js-show-content-block-templates add-new-content-block-button"
              tabindex="-1"
            >
              <i class="fas fa-plus"></i>
            </button>
          `, {
            title: "Inhaltsblock am Anfang hinzufügen",
            text: "Fügt ganz oben auf der Seite einen neuen Inhaltsblock aus einer Vorlage hinzu.",
            delay: 1500
          })}
        </div>
      </div>

      ${contentBlocks && contentBlocks.join("")}
    </div>
  `
}

App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock = function(contentBlockHTML, {contentBlockId, draftContentBlockIndex, context, updateUrl, destroyUrl, updatePositionUrl, aiUrl, toolbarPosition} = {}) {
  const isSiteContext = context === 'site';
  const showEmptyHint = !context || context === 'projekt';
  const isEmpty = showEmptyHint && App.Studio.ContentBlocks.Crud.isContentEmpty(contentBlockHTML);
  const emptyHintClasses = `${showEmptyHint ? ' js-toggle-empty-hint-on-content' : ''}${isEmpty ? ' is-content-empty' : ''}`;

  return `
    <div
      class="js-content-block-wrapper custom-content-block-wrapper${emptyHintClasses} ${draftContentBlockIndex ? ' -draft' : ''}"
      data-content-block-id="${contentBlockId ? contentBlockId : ''}"
      data-draft-index="${draftContentBlockIndex !== undefined ? draftContentBlockIndex : ''}"
      data-draft="${draftContentBlockIndex ? true : false}"
      data-edit-mode=""
      ${updateUrl ? `data-update-url="${updateUrl}"` : ''}
      ${destroyUrl ? `data-destroy-url="${destroyUrl}"` : ''}
      ${updatePositionUrl ? `data-update-position-url="${updatePositionUrl}"` : ''}
      ${aiUrl ? `data-ai-url="${aiUrl}"` : ''}
      ${toolbarPosition ? `data-toolbar-position="${toolbarPosition}"` : ''}
      data-context="${context || 'projekt'}"
      >
      <div class="custom-content-block-wrapper--inner">
        <div class="custom-content-block--toolbar-zone js-studio-hide-on-preview">
        <div class="custom-content-block--toolbar">

            <div class="custom-content-block-edit--buttons-wrapper">
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  type="button"
                  class="studio-edit-button -green js-save-content-block"
                  tabindex="-1"
                >
                  <i class="fas fa-save"></i>
                  Speichern
                </button>
              `, {
                title: "Speichern",
                text: "Speichert alle Änderungen an diesem Inhaltsblock und beendet den Bearbeitungsmodus.",
                delay: 3500
              })}
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  type="button"
                  class="studio-edit-button js-cancel-content-block"
                  tabindex="-1"
                >
                  <i class="fas fa-xmark"></i>
                  Abbrechen
                </button>
              `, {
                title: "Abbrechen",
                text: "Verwirft alle nicht gespeicherten Änderungen und setzt den Block auf den zuletzt gespeicherten Stand zurück.",
                delay: 3500
              })}
            </div>
            <div
              class="custom-content-block-edit custom-content-block--mode-controlls js-simple-edit-mode-controlls d-flex-justify-space-between">
              <div class="content-block-edit-toolbar">
                <div
                  class="content-block-margin-input d-flex align-items-center u-gap-5"
                >
                  ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                    <i class="fas fa-arrows-alt-v content-block-margin-input--icon"></i>
                  `, {
                    title: "Abstand nach unten",
                    text: "Bestimmt den vertikalen Außenabstand unterhalb dieses Inhaltsblocks und damit, wie viel Platz bis zum nächsten Block frei bleibt. Über die Felder − und + in Schritten verändern oder den Wert direkt eintippen.",
                    note: "Wertebereich 15–85 px · Schrittweite 5 px · Standard 30 px",
                    delay: 200
                  })}
                  <button
                    type="button"
                    class="content-block-margin-input--step js-content-block-margin-bottom-decrease"
                    aria-label="Abstand verringern"
                    tabindex="-1"
                  >
                    <i class="fas fa-minus"></i>
                  </button>
                  <input
                    type="number"
                    class="js-content-block-margin-bottom-input"
                    value="30"
                    step="5"
                    min="15"
                    max="85"
                  >
                  <button
                    type="button"
                    class="content-block-margin-input--step js-content-block-margin-bottom-increase"
                    aria-label="Abstand vergrößern"
                    tabindex="-1"
                  >
                    <i class="fas fa-plus"></i>
                  </button>
                </div>
                ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                  <dropdown-select-menu
                    name="header-type"
                    title="Überschrift"
                    selected="Text"
                    toggle-tabindex="-1"
                    container-css-class="js-content-block-header-dropdown"
                    item-css-class="js-content-block-header-option"
                  >
                    <option data-header-type="h2">H2</option>
                    <option data-header-type="h3">H3</option>
                    <option data-header-type="none">Text</option>
                  </dropdown-select-menu>
                `, {
                  title: "Überschrift",
                  text: "Wandelt den markierten Text in eine Überschrift (H2 oder H3) um oder setzt ihn auf normalen Fließtext zurück.",
                  delay: 1200
                })}
                ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                  <button
                    type="button"
                    tabindex="-1"
                    class="studio-icon-button js-content-block-toggle-bold"
                  >
                    <i class="fas fa-bold"></i>
                  </button>
                `, {
                  title: "Fett",
                  text: "Formatiert den markierten Text fett oder hebt die Fettformatierung wieder auf."
                })}
                ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                  <button
                    type="button"
                    disabled
                    tabindex="-1"
                    class="studio-icon-button js-content-block-add-link"
                  >
                    <i class="fas fa-link"></i>
                  </button>
                `, {
                  title: "Link hinzufügen",
                  text: "Wandelt den markierten Text in einen Link um. Markieren Sie zuerst Text, um diese Funktion zu aktivieren."
                })}
                ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                  <button
                    type="button"
                    disabled
                    tabindex="-1"
                    class="studio-icon-button js-content-block-insert-file-link"
                  >
                    <i class="fas fa-paperclip"></i>
                  </button>
                `, {
                  title: "Datei-Link einfügen",
                  text: "Fügt in den markierten Text einen Link zu einer hochgeladenen Datei ein. Markieren Sie zuerst Text, um diese Funktion zu aktivieren."
                })}
              </div>
            </div>
            <div class="custom-content-block-edit custom-content-block-edit-main-controlls js-content-block-edit-main-controlls">
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  type="button"
                  tabindex="-1"
                  class="js-edit-text-content-block studio-icon-button"
                >
                  <i class="fas fa-pencil-alt"></i>
                </button>
              `, {
                delay: 1000,
                title: "Text-Editor",
                text: "Öffnet den einfachen Editor zur direkten und intuitiven Bearbeitung des Textinhalts mit Grundformatierung."
              })}
              <div class="studio-icon-button-wrapper">
                ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                  <button
                    type="button"
                    tabindex="-1"
                    class="js-content-block-enter-ai-edit-mode studio-icon-button ${App.Studio.Projekt.config.aiAvailable ? "" : "ai-feature-disabled"}"
                  >
                    <i class="fas fa-magic"></i>
                  </button>
                `, {
                  delay: 1000,
                  title: "KI-Editor",
                  text: "Nutzen Sie künstliche Intelligenz mit individuellen Anweisungen, um diesen Block zu modifizieren, umzugestalten oder zu verbessern.",
                  note: App.Studio.Projekt.config.aiAvailable ? null : App.Studio.Projekt.templateFunctions.aiDisabledTooltipNote
                })}
              </div>
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  type="button"
                  tabindex="-1"
                  class="js-content-block-enter-code-edit-mode studio-icon-button"
                >
                  <i class="fas fa-code"></i>
                </button>
              `, {
                delay: 1000,
                title: "Code-Editor",
                text: "Öffnet den erweiterten Code-Editor für fortgeschrittene HTML- und CSS-Bearbeitung mit Syntax-Highlighting."
              })}
              <!-- <button -->
              <!--   data-tooltip -->
              <!--   data-hover-delay="800" -->
              <!--   tabindex="-1" -->
              <!--   title="Erweiterter Editor&#10;Öffnet den erweiterten HTML-Editor mit vollständiger Formatierungsunterstützung und erweiterten Bearbeitungsfunktionen" -->
              <!--   class="studio-icon-button js-html-edit-content-block" -->
              <!-- > -->
              <!--   <i class="fas fa-edit"> -->
              <!--   </i> -->
              <!-- </button> -->
              <div class="custom-content-block-edit--separator"></div>
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  type="button"
                  tabindex="-1"
                  class="js-copy-current-content-block studio-icon-button"
                >
                  <i class="fas fa-copy"></i>
                </button>
              `, {
                delay: 1000,
                title: "Duplizieren",
                text: "Erstellt eine exakte Kopie dieses Inhaltsblocks direkt darunter — mit allen Einstellungen."
              })}
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  tabindex="-1"
                  disabled
                  class="studio-icon-button js-content-block-version-managment"
                >
                  <i class="fa fa-arrow-rotate-left fa-undo"></i>
                </button>
              `, {
                delay: 1000,
                title: "Versionsverlauf",
                text: "Zeigt frühere Versionen dieses Blocks an und macht Änderungen rückgängig."
              })}
              ${isSiteContext ? `
              <div class="custom-content-block-edit--separator"></div>
              <button
                type="button"
                tabindex="-1"
                data-hint="Vorlage anwenden&#10;Ersetzt den Inhalt dieses Blocks durch eine ausgewählte Vorlage"
                class="studio-icon-button js-open-template-selector-for-replace"
              >
                <i class="fas fa-exchange-alt">
                </i>
              </button>
              <div class="custom-content-block-edit--separator"></div>
              <button
                type="button"
                tabindex="-1"
                data-hint="Entfernt den gesamten Inhalt dieses Blocks"
                class="studio-icon-button -delete js-clear-site-content-block"
              >
                <i class="fas fa-eraser">
                </i>
              </button>
              ` : `
              <div class="custom-content-block-edit--separator"></div>
              <button
                class="studio-icon-button custom-content-block--move-button js-dnd-handle"
                title="Inhaltsbock verschieben"
                tabindex="-1"
              >
                <i class="fas fa-up-down-left-right"></i>
              </button>
              <div class="custom-content-block-edit--separator"></div>
              ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
                <button
                  type="button"
                  tabindex="-1"
                  class="js-delete-content-block -delete studio-icon-button"
                >
                  <i class="fas fa-trash-alt"></i>
                </button>
              `, {
                delay: 1000,
                title: "Inhaltsblock löschen",
                text: "Entfernt diesen Inhaltsblock dauerhaft von der Seite. Diese Aktion kann nicht rückgängig gemacht werden."
              })}
              `}

            </div>

            <div class="custom-content-block-edit custom-content-block--mode-controlls js-html-edit-mode-controlls">
            </div>

            <div class="custom-content-block-edit custom-content-block--mode-controlls js-code-edit-mode-controlls">
            </div>
        </div>
        </div>

        <div class="custom-content-block--toolbar-border js-content-block--toolbar-anchor js-studio-hide-on-preview"></div>

        ${showEmptyHint ? App.Studio.Projekt.templateFunctions.contentBlockEmptyHintHtml() : ''}

        <div class="custom-content-block js-content-block" data-id="${contentBlockId ? contentBlockId : ''}">
          ${contentBlockHTML}
        </div>

        <div class="custom-content-block--overlay">
        </div>
      </div>

      ${isSiteContext ? '' : showContentBlockTemplatesButton(!!draftContentBlockIndex)}
    </div>
  `.trim()
}

function showContentBlockTemplatesButton(isDraft = false) {
  return `
    <div class="add-new-content-block-section js-show-content-block-templates-section js-studio-hide-on-preview">
      <div class="add-new-content-block-section--controls">
        ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
          <button
            type="button"
            class="add-new-content-block-floating-control add-new-content-block-blank-button js-add-blank-content-block"
            tabindex="-1"
            ${isDraft ? "disabled" : ''}
          >
            <i class="far fa-file"></i>
          </button>
        `, {
          title: "Leeren Inhaltsblock hinzufügen",
          text: "Fügt an dieser Stelle einen leeren Inhaltsblock hinzu, den Sie selbst gestalten.",
          delay: 1500
        })}
        ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
          <button
            type="button"
            class="js-show-content-block-templates add-new-content-block-button"
            tabindex="-1"
            ${isDraft ? "disabled" : ''}
          >
            <i class="fas fa-plus"></i>
          </button>
        `, {
          title: "Inhaltsblock hinzufügen",
          text: "Fügt an dieser Stelle einen neuen Inhaltsblock aus einer Vorlage hinzu.",
          delay: 1500
        })}
      </div>
    </div>
  `
}

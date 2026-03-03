const html = (strings, ...values) => {
  return String.raw(strings, ...values);
};

ProjektStudio.templateFunctions.emptyContentBlockHtml = '<div><p></p></div>';

ProjektStudio.templateFunctions.wrapWithContentBlockListHtml = function(contentBlocks, projektId) {
  return `
    <div
      data-sort-url="/projekts/${projektId}/content_blocks/sort"
      class="js-content-blocks-list content-blocks-container"
    >
      <div
        class="js-add-first-content-block-wrapper add-first-content-block-wrapper js-projekt-content-block-wrapper projekt-content-block-wrapper projekt-content-block-wrapper js-projekt-studio-hide-on-preview"
        style="display: ${contentBlocks.length <= 0 ? 'none' : ''}"
      >
        ${showContentBlockTemplatesButton()}
      </div>

      ${contentBlocks && contentBlocks.join("")}
    </div>
  `
}

ProjektStudio.templateFunctions.addStudioControlsToContentBlock = function(contentBlockHTML, {contentBlockId, draftContentBlockIndex} = {}) {
  return `
    <div
      class="js-content-block js-projekt-content-block-wrapper projekt-content-block-wrapper projekt-content-block-wrapper ${draftContentBlockIndex ? ' -draft' : ''}"
      data-content-block-id="${contentBlockId ? contentBlockId : ''}"
      data-draft-index="${draftContentBlockIndex !== undefined ? draftContentBlockIndex : ''}"
      data-draft="${draftContentBlockIndex ? true : false}"
      data-edit-mode=""
      >
      <div class="relative">
        <div class="projekt-content-block--toolbar js-projekt-studio-hide-on-preview">

            <div class="projekt-content-block-edit projekt-content-block-edit-main-controlls js-projekt-content-block-edit-main-controlls">
              <div class="ai-button-wrapper">
                <div class="ai-button-wrapper--inner">
                  <button
                    type="button"
                    data-tooltip
                    data-position="left"
                    data-hover-delay="800"
                    tabindex="0"
                    title="AI-Generierung&#10;Ermöglicht KI-gestützte Erstellung, Bearbeitung und Verbesserung dieses Inhaltsblocks mit erweiterten Funktionen"
                    class="projekt-frame-icon-button js-projekt-content-block--ai-edit"
                  >
                    <i class="dt-logo-small-icon">
                    </i>
                  </button>
                </div>
                <div class="ai-button--lock-overlay" title="Anderer KI-Prozess läuft"></div>
              </div>
              <button
                type="button"
                data-tooltip
                data-hover-delay="800"
                tabindex="0"
                title="Text-Editor&#10;Öffnet den einfachen Editor zur direkten und intuitiven Bearbeitung des Textinhalts mit Grundformatierung"
                class="js-edit-text-projekt-content-block projekt-frame-icon-button"
              >
                <i class="fas fa-pencil-alt">
                </i>
              </button>
              <div class="projekt-frame-icon-button-wrapper">
                <button
                  type="button"
                  data-tooltip
                  data-hover-delay="800"
                  tabindex="0"
                  title="KI-Editor&#10;Nutzen Sie künstliche Intelligenz mit individuellen Anweisungen um diesen Block zu modifizieren, umzugestalten oder zu verbessern"
                  class="js-content-block-enter-ai-edit-mode projekt-frame-icon-button"
                >
                  <i class="fas fa-magic">
                  </i>
                </button>
              </div>
              <button
                type="button"
                data-tooltip
                data-hover-delay="800"
                tabindex="0"
                title="Code-Editor&#10;Öffnet den erweiterten Code-Editor für fortgeschrittene HTML- und CSS-Bearbeitung mit Syntax-Highlighting"
                class="js-content-block-enter-code-edit-mode projekt-frame-icon-button"
              >
                <i class="fas fa-code">
                </i>
              </button>
              <button
                data-tooltip
                data-hover-delay="800"
                tabindex="0"
                title="Erweiterter Editor&#10;Öffnet den erweiterten HTML-Editor mit vollständiger Formatierungsunterstützung und erweiterten Bearbeitungsfunktionen"
                class="projekt-frame-icon-button js-html-edit-content-block"
              >
                <i class="fas fa-edit">
                </i>
              </button>
              <div class="projekt-content-block-edit--separator"></div>
              <button
                type="button"
                data-tooltip
                data-hover-delay="800"
                tabindex="0"
                title="Duplizieren&#10;Erstellt eine exakte Kopie dieses Inhaltsblocks mit allen Einstellungen direkt unterhalb des aktuellen Blocks"
                class="js-copy-current-content-block projekt-frame-icon-button"
              >
                <i class="fas fa-copy">
                </i>
              </button>
              <button
                data-tooltip
                data-hover-delay="800"
                tabindex="0"
                title="Versionsverlauf&#10;Verwalten Sie Versionen dieses Blocks: Anzeigen vorheriger Versionen und Rückgängigmachen von Änderungen"
                disabled
                class="projekt-frame-icon-button js-content-block-version-managment"
              >
                <i class="fa fa-arrow-rotate-left fa-undo">
                </i>
              </button>
              <div class="projekt-content-block-edit--separator"></div>
              <button
                class="projekt-frame-icon-button projekt-content-block--move-button js-dnd-handle"
                title="Inhaltsbock verschieben"
              >
                <i class="fas fa-up-down-left-right"></i>
              </button>
              <div class="projekt-content-block-edit--separator"></div>
              <button
                type="button"
                tabindex="0"
                class="js-delete-projekt-content-block -delete projekt-frame-icon-button"
              >
                <i class="fas fa-trash-alt">
                </i>
              </button>

            </div>
            <div
              class="projekt-content-block-edit projekt-content-block--mode-controlls js-simple-edit-mode-controlls d-flex-justify-space-between">
              <div class="content-block-edit-toolbar">
                <label
                  class="content-block-margin-input d-flex align-items-end u-gap-5"
                  data-tooltip
                  data-hover-delay="800"
                  title="Abstand nach unten"
                >
                  <i class="fas fa-arrows-alt-v"></i>
                  <input
                    type="number"
                    class="js-content-block-margin-bottom-input"
                    value="35"
                    step="5"
                    min="0"
                    max="85"
                  >
                </label>
                <div
                  class="dropdown-select-container js-dropdown-select-menu js-content-block-header-dropdown"
                  data-name="header-type"
                  data-tooltip
                  data-hover-delay="800"
                  title="Überschrift"
                >
                  <button
                    type="button"
                    class="dropdown-select-menu-toggle js-dropdown-select-menu-toggle click-dropdown"
                    aria-haspopup="listbox"
                    aria-expanded="false"
                    aria-label="Überschrift"
                  >
                    Text
                  </button>
                  <ul
                    class="dropdown-select-menu--list"
                    role="listbox"
                    aria-label="Überschrift"
                    tabindex="-1"
                  >
                    <li
                      class="js-dropdown-select-menu-item js-content-block-header-option dropdown-select-menu-item"
                      role="option"
                      tabindex="-1"
                      data-index="0"
                      data-header-type="h2"
                    >
                      H2
                    </li>
                    <li
                      class="js-dropdown-select-menu-item js-content-block-header-option dropdown-select-menu-item"
                      role="option"
                      tabindex="-1"
                      data-index="1"
                      data-header-type="h3"
                    >
                      H3
                    </li>
                    <li
                      class="js-dropdown-select-menu-item js-content-block-header-option dropdown-select-menu-item"
                      role="option"
                      tabindex="-1"
                      data-index="2"
                      data-header-type="none"
                    >
                      Text
                    </li>
                  </ul>
                </div>
                <button
                  type="button"
                  data-tooltip
                  data-hover-delay="800"
                  tabindex="0"
                  title="Text fett formatieren"
                  class="projekt-frame-icon-button js-content-block-toggle-bold"
                >
                  <i class="fas fa-bold"></i>
                </button>
                <button
                  type="button"
                  disabled
                  data-tooltip
                  data-hover-delay="800"
                  tabindex="0"
                  title="Link hinzufügen"
                  class="projekt-frame-icon-button js-content-block-add-link"
                >
                  <i class="fas fa-link"></i>
                </button>
              </div>
            </div>

            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-html-edit-mode-controlls">
            </div>

            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-code-edit-mode-controlls">
            </div>
            <div class="d-flex projekt-content-block-edit--buttons-wrapper">
              <button
                type="button"
                class="projekt-content-block-edit--button -green js-save-content-block"
              >
                <i class="fas fa-save"></i>
                Speichern
              </button>
              <button
                type="button"
                class="projekt-content-block-edit--button js-cancel-content-block"
              >
                <i class="fas fa-xmark"></i>
                Abbrechen
              </button>
            </div>
        </div>

        <div class="projekt-content-block--toolbar-border js-projekt-content-block--toolbar-anchor js-projekt-studio-hide-on-preview"></div>

        <div class="projekt-content-block js-projekt-content-block">
          ${contentBlockHTML}
        </div>

        <div class="projekt-content-block--overlay">
        </div>
      </div>

      ${showContentBlockTemplatesButton(!!draftContentBlockIndex)}
    </div>
  `.trim()
}

function showContentBlockTemplatesButton(isDraft = false) {
  return `
    <div class="add-new-content-block-section js-show-content-block-templates-section js-projekt-studio-hide-on-preview">
      <button
        type="button"
        class="js-show-content-block-templates add-new-content-block-button"
        title="Neuen Inhaltsblock hinzufügen"
        ${isDraft ? "disabled" : ''}
      >
        <i class="fas fa-plus"></i>
      </button>
    </div>
  `
}

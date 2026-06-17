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
        class="add-new-content-block-section js-show-content-block-templates-section js-add-content-block-at-top -at-top js-studio-hide-on-preview"
        style="display: ${contentBlocks.length <= 0 ? 'none' : ''}"
      >
        <button
          type="button"
          class="studio-edit-button -green content-block-templates-selector--ai-create js-open-create-content-block-with-ai"
          title="Inhaltsblock mit KI erstellen"
          tabindex="-1"
        >
          <i class="fas fa-magic"></i>
        </button>
        <button
          type="button"
          class="js-show-content-block-templates add-new-content-block-button"
          title="Neuen Inhaltsblock am Anfang hinzufügen"
          tabindex="-1"
        >
          <i class="fas fa-plus"></i>
        </button>
      </div>

      ${contentBlocks && contentBlocks.join("")}
    </div>
  `
}

ProjektStudio.templateFunctions.addStudioControlsToContentBlock = function(contentBlockHTML, {contentBlockId, draftContentBlockIndex, context, updateUrl, destroyUrl, updatePositionUrl, aiUrl, toolbarPosition} = {}) {
  const isSiteContext = context === 'site';

  return `
    <div
      class="js-content-block-wrapper projekt-content-block-wrapper ${draftContentBlockIndex ? ' -draft' : ''}"
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
      <div class="projekt-content-block-wrapper--inner">
        <div class="projekt-content-block--toolbar-zone js-studio-hide-on-preview">
        <div class="projekt-content-block--toolbar">

            <div class="projekt-content-block-edit--buttons-wrapper">
              <button
                type="button"
                class="studio-edit-button -green js-save-content-block"
                tabindex="-1"
              >
                <i class="fas fa-save"></i>
                Speichern
              </button>
              <button
                type="button"
                class="studio-edit-button js-cancel-content-block"
                tabindex="-1"
              >
                <i class="fas fa-xmark"></i>
                Abbrechen
              </button>
            </div>
            <div
              class="projekt-content-block-edit projekt-content-block--mode-controlls js-simple-edit-mode-controlls d-flex-justify-space-between">
              <div class="content-block-edit-toolbar">
                <div
                  class="content-block-margin-input d-flex align-items-center u-gap-5"
                  data-hint="Abstand nach unten"
                >
                  <i class="fas fa-arrows-alt-v"></i>
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
                    min="20"
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
                <div
                  class="dropdown-select-container js-dropdown-select-menu js-content-block-header-dropdown"
                  data-name="header-type"
                  data-hint="Überschrift"
                >
                  <button
                    type="button"
                    class="dropdown-select-menu-toggle js-dropdown-select-menu-toggle click-dropdown"
                    aria-haspopup="listbox"
                    aria-expanded="false"
                    aria-label="Überschrift"
                    tabindex="-1"
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
                  tabindex="-1"
                  data-hint="Text fett formatieren"
                  class="studio-icon-button js-content-block-toggle-bold"
                >
                  <i class="fas fa-bold"></i>
                </button>
                <button
                  type="button"
                  disabled
                  tabindex="-1"
                  data-hint="Link hinzufügen"
                  class="studio-icon-button js-content-block-add-link"
                >
                  <i class="fas fa-link"></i>
                </button>
                <button
                  type="button"
                  disabled
                  tabindex="-1"
                  data-hint="Datei-Link einfügen"
                  class="studio-icon-button js-content-block-insert-file-link"
                >
                  <i class="fas fa-paperclip"></i>
                </button>
              </div>
            </div>
            <div class="projekt-content-block-edit projekt-content-block-edit-main-controlls js-content-block-edit-main-controlls">
              <button
                type="button"
                tabindex="-1"
                data-hint="Text-Editor&#10;Öffnet den einfachen Editor zur direkten und intuitiven Bearbeitung des Textinhalts mit Grundformatierung"
                class="js-edit-text-content-block studio-icon-button"
              >
                <i class="fas fa-pencil-alt">
                </i>
              </button>
              <div class="studio-icon-button-wrapper">
                <button
                  type="button"
                  tabindex="-1"
                  data-hint="KI-Editor&#10;Nutzen Sie künstliche Intelligenz mit individuellen Anweisungen um diesen Block zu modifizieren, umzugestalten oder zu verbessern"
                  class="js-content-block-enter-ai-edit-mode studio-icon-button"
                >
                  <i class="fas fa-magic">
                  </i>
                </button>
              </div>
              <button
                type="button"
                tabindex="-1"
                data-hint="Code-Editor&#10;Öffnet den erweiterten Code-Editor für fortgeschrittene HTML- und CSS-Bearbeitung mit Syntax-Highlighting"
                class="js-content-block-enter-code-edit-mode studio-icon-button"
              >
                <i class="fas fa-code">
                </i>
              </button>
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
              <div class="projekt-content-block-edit--separator"></div>
              <button
                type="button"
                tabindex="-1"
                data-hint="Duplizieren&#10;Erstellt eine exakte Kopie dieses Inhaltsblocks mit allen Einstellungen direkt unterhalb des aktuellen Blocks"
                class="js-copy-current-content-block studio-icon-button"
              >
                <i class="fas fa-copy">
                </i>
              </button>
              <button
                tabindex="-1"
                data-hint="Versionsverlauf&#10;Verwalten Sie Versionen dieses Blocks: Anzeigen vorheriger Versionen und Rückgängigmachen von Änderungen"
                disabled
                class="studio-icon-button js-content-block-version-managment"
              >
                <i class="fa fa-arrow-rotate-left fa-undo">
                </i>
              </button>
              ${isSiteContext ? `
              <div class="projekt-content-block-edit--separator"></div>
              <button
                type="button"
                tabindex="-1"
                data-hint="Vorlage anwenden&#10;Ersetzt den Inhalt dieses Blocks durch eine ausgewählte Vorlage"
                class="studio-icon-button js-open-template-selector-for-replace"
              >
                <i class="fas fa-exchange-alt">
                </i>
              </button>
              <div class="projekt-content-block-edit--separator"></div>
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
              <div class="projekt-content-block-edit--separator"></div>
              <button
                class="studio-icon-button projekt-content-block--move-button js-dnd-handle"
                title="Inhaltsbock verschieben"
                tabindex="-1"
              >
                <i class="fas fa-up-down-left-right"></i>
              </button>
              <div class="projekt-content-block-edit--separator"></div>
              <button
                type="button"
                tabindex="-1"
                class="js-delete-content-block -delete studio-icon-button"
              >
                <i class="fas fa-trash-alt">
                </i>
              </button>
              `}

            </div>

            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-html-edit-mode-controlls">
            </div>

            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-code-edit-mode-controlls">
            </div>
        </div>
        </div>

        <div class="projekt-content-block--toolbar-border js-content-block--toolbar-anchor js-studio-hide-on-preview"></div>

        <div class="projekt-content-block js-content-block" data-id="${contentBlockId ? contentBlockId : ''}">
          ${contentBlockHTML}
        </div>

        <div class="projekt-content-block--overlay">
        </div>
      </div>

      ${isSiteContext ? '' : showContentBlockTemplatesButton(!!draftContentBlockIndex)}
    </div>
  `.trim()
}

function showContentBlockTemplatesButton(isDraft = false) {
  return `
    <div class="add-new-content-block-section js-show-content-block-templates-section js-studio-hide-on-preview">
      <button
        type="button"
        class="studio-edit-button -green content-block-templates-selector--ai-create js-open-create-content-block-with-ai"
        title="Inhaltsblock mit KI erstellen"
        tabindex="-1"
        ${isDraft ? "disabled" : ''}
      >
        <i class="fas fa-magic"></i>
      </button>
      <button
        type="button"
        class="js-show-content-block-templates add-new-content-block-button"
        title="Neuen Inhaltsblock hinzufügen"
        tabindex="-1"
        ${isDraft ? "disabled" : ''}
      >
        <i class="fas fa-plus"></i>
      </button>
    </div>
  `
}

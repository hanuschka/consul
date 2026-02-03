const html = (strings, ...values) => {
  return String.raw(strings, ...values);
};

ProjektStudio.templateFunctions.emptyContentBlockHtml = '<div><p></p></div>';

ProjektStudio.templateFunctions.wrapWithContentBlockListHtml = function(contentBlocks, projektId) {
  return `
    <div
      data-sort-url="/projekts/${projektId}/content_blocks/sort"
      class="js-content-blocks-container content-blocks-container"
    >
      <div
        class="js-add-first-content-block-wrapper js-projekt-content-block-wrapper projekt-content-block-wrapper projekt-content-block-wrapper"
        style="display: ${contentBlocks.length <= 0 ? 'none' : ''}"
      >
        <div class="js-projekt-add-new-content-block--top-button">
          ${showContentBlockTemplatesButton()}
        </div>
      </div>

      ${contentBlocks && contentBlocks.join("")}
    </div>
  `
}

ProjektStudio.templateFunctions.addStudioControlsToContentBlock = function(contentBlockHTML, {contentBlockId, draftContentBlockIndex} = {}) {
  return `
    <div
      class="js-projekt-content-block-wrapper projekt-content-block-wrapper projekt-content-block-wrapper ${draftContentBlockIndex ? ' -draft' : ''}"
      data-content-block-id="${contentBlockId ? contentBlockId : ''}"
      data-draft-index="${draftContentBlockIndex !== undefined ? draftContentBlockIndex : ''}"
      data-draft="${draftContentBlockIndex ? true : false}"
      >
      <div class="relative">
        <div class="projekt-content-block js-projekt-content-block">
          ${contentBlockHTML}
        </div>

        <div class="projekt-content-block--overlay">
        </div>

        <div class="projekt-content-block--toolsets">
            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-ai-edit-mode-controlls d-flex-justify-space-between">
              <div class="d-flex u-gap-10">
                <button type="button" class="projekt-content-block-edit--button -green js-content-block-ai-edit-save">
                  <i class="fas fa-save"></i>
                  Speichern
                </button>
                <button type="button" class="projekt-content-block-edit--button js-content-block-ai-edit-cancel">
                  <i class="fas fa-xmark"></i>
                  Abbrechen
                </button>
              </div>
              <div class="d-flex u-gap-10">
                <button type="button" class="projekt-content-block-edit--button js-content-block-enter-simple-edit-mode-from-ai">
                  <i class="fas fa-pencil-alt"></i>
                  Im Editor weiterbearbeiten
                </button>
              </div>
            </div>

            <div
              class="projekt-content-block-edit projekt-content-block--mode-controlls js-simple-edit-mode-controlls d-flex-justify-space-between">
              <div class="d-flex u-gap-10">
                <button type="button" class="projekt-content-block-edit--button -green js-save-edit-text-projekt-content-block">
                  <i class="fas fa-save"></i>
                  Speichern
                </button>
                <button type="button" class="projekt-content-block-edit--button js-projekt-content-block--text-edit-cancel">
                  <i class="fas fa-xmark"></i>
                  Abbrechen
                </button>
              </div>

              <div class="content-block-edit-toolbar">
                <label class="content-block-margin-input d-flex align-items-end u-gap-5">
                  <span>Abstand unten</span>
                  <input
                    type="number"
                    class="js-content-block-margin-bottom-input"
                    value="35"
                    step="5"
                    min="0"
                    max="85"
                  >
                </label>
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
                <button
                  type="button"
                  data-tooltip
                  data-hover-delay="800"
                  tabindex="0"
                  title="Mit KI bearbeiten"
                  class="projekt-frame-icon-button js-content-block-enter-ai-edit-mode-from-simple"
                >
                  <i class="fas fa-magic"></i>
                </button>
              </div>
            </div>

            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-html-edit-mode-controlls">
              <button type="button" class="projekt-content-block-edit--button -green js-save-edit-html-projekt-content-block">
                <i class="fas fa-save"></i>
                Speichern
              </button>
              <button type="button" class="projekt-content-block-edit--button js-projekt-content-block--html-edit-cancel">
                <i class="fas fa-xmark"></i>
                Abbrechen
              </button>
            </div>

            <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-code-edit-mode-controlls d-flex-justify-space-between">
              <div class="d-flex u-gap-10">
                <button type="button" class="projekt-content-block-edit--button -green js-save-edit-code-projekt-content-block">
                  <i class="fas fa-save"></i>
                  Speichern
                </button>
                <button type="button" class="projekt-content-block-edit--button js-projekt-content-block--code-edit-cancel">
                  <i class="fas fa-xmark"></i>
                  Abbrechen
                </button>
              </div>
            </div>
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
              <div class="ai-button-wrapper">
                <div class="ai-button-wrapper--inner">
                  <div class="dropdown-menu-container js-dropdown-menu">
                    <div class="js-dropdown-menu-toggle">
                      <button
                        type="button"
                        data-tooltip
                        data-hover-delay="800"
                        tabindex="0"
                        title="KI-Umgestaltung&#10;Wählen Sie eine vordefinierte Option zur KI-basierten automatischen Transformation und Anpassung des Textes"
                        class="projekt-frame-icon-button"
                      >
                        <i class="fas fa-arrows-rotate ">
                        </i>
                      </button>

                    </div>
                    <div class="dropdown-menu-list">
                      <div class="js-dropdown-menu-item dropdown-menu-item ">
                        <div class="js-projekt-content-block--regenerate" data-regenerate-type="regenerate">
                          Text neu erstellen
                        </div>

                      </div>
                      <div class="js-dropdown-menu-item dropdown-menu-item ">
                        <div class="js-projekt-content-block--regenerate" data-regenerate-type="make_shorter">
                          Text kürzen
                        </div>

                      </div>
                      <div class="js-dropdown-menu-item dropdown-menu-item ">
                        <div class="js-projekt-content-block--regenerate" data-regenerate-type="make_longer">
                          Text verlängern
                        </div>

                      </div>
                      <div class="js-dropdown-menu-item dropdown-menu-item ">
                        <div class="js-projekt-content-block--regenerate" data-regenerate-type="use_youth_language">
                          Jugendsprache
                        </div>

                      </div>
                      <div class="js-dropdown-menu-item dropdown-menu-item ">
                        <div class="js-projekt-content-block--regenerate" data-regenerate-type="use_simple_language">
                          Leichte Sprache
                        </div>

                      </div>
                    </div>
                  </div>
                </div>
                <div class="ai-button--lock-overlay" title="Anderer KI-Prozess läuft"></div>
              </div>
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
              <button
                class="projekt-frame-icon-button projekt-content-block--move-button js-dnd-handle"
                title="Inhaltsbock verschieben"
              >
                <i class="fas fa-up-down-left-right"></i>
              </button>
              <button
                type="button"
                data-tooltip
                data-position="left"
                data-hover-delay="800"
                tabindex="0"
                title="Löschen&#10;Entfernt diesen Inhaltsblock endgültig aus dem Projekt. Warnung: Diese Aktion kann nicht rückgängig gemacht werden"
                class="js-delete-projekt-content-block -delete projekt-frame-icon-button"
              >
                <i class="fas fa-trash-alt">
                </i>
              </button>

            </div>
        </div>
      </div>

      ${showContentBlockTemplatesButton(!!draftContentBlockIndex)}
    </div>
  `.trim()
}

function showContentBlockTemplatesButton(isDraft = false) {
  return `
    <div class="add-new-content-block-section js-show-content-block-templates-section">
      <button
        type="button"
        class="js-show-content-block-templates add-new-content-block-button"
        title="Neuen Inhaltsblock hinzufügen"
        ${isDraft ? "disabled" : ''}
      >
        <i class="fas fa-plus"></i>
        Neuen Inhaltsblock hinzufügen
      </button>
    </div>
  `
}

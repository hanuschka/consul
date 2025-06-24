function html(content) {
  return content;
}

export function addNewContentBlockButtonToContentBlockList(contentBlocksHtml, projektId) {
  return `
    <div
      data-sort-url="/projekts/${projektId}/content_blocks/sort"
      class="js-content-blocks-container content-blocks-container"
    >
      ${contentBlocksHtml}
    </div>
  `
}

export function addStudioControlsToContentBlock(contentBlockHTML, {contentBlockId, draftContentBlockIndex}) {
  return `
    <div
      class="js-projekt-content-block-edit-section projekt-content-block-edit-section projekt-content-block-wrapper"
      data-content-block-id="${contentBlockId ? contentBlockId : ''}"
      data-draft-index="${draftContentBlockIndex !== undefined ? draftContentBlockIndex : ''}"
      >
      <div class="relative">
        <div class="projekt-content-block">
          ${contentBlockHTML}
        </div>

        <div class="projekt-content-block--overlay">
        </div>

        <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-ai-edit-mode-controlls">
          <div class="ai-edit-mode--loader bars-scale-loader">
          </div>
          <button type="button" class="projekt-content-block-edit--button js-projekt-content-block--ai-edit-cancel">
            <i class="fas fa-xmark"></i>
            Abbrechen
          </button>
        </div>

        <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-text-edit-mode-controlls">
          <button type="button" class="projekt-content-block-edit--button -green js-save-edit-text-projekt-content-block">
            <i class="fas fa-save"></i>
            Speichern
          </button>
          <button type="button" class="projekt-content-block-edit--button js-projekt-content-block--text-edit-cancel">
            <i class="fas fa-xmark"></i>
            Abbrechen
          </button>
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

        <div class="projekt-content-block-edit projekt-content-block--mode-controlls js-code-edit-mode-controlls">
          <button type="button" class="projekt-content-block-edit--button -green js-save-edit-code-projekt-content-block">
            <i class="fas fa-save"></i>
            Speichern
          </button>
          <button type="button" class="projekt-content-block-edit--button js-projekt-content-block--code-edit-cancel">
            <i class="fas fa-xmark"></i>
            Abbrechen
          </button>
        </div>

        <div class="projekt-content-block-edit projekt-content-block-edit-standard-controlls js-projekt-content-block-edit-standard-controlls">
          <div class="ai-button-wrapper">
            <div class="ai-button-wrapper--inner">
              <button type="button" data-original-title="AI für diesen Block aktivieren" title="AI für diesen Block aktivieren" class="projekt-frame-icon-button js-projekt-content-block--ai-edit">
                <i class="dt-logo-small-icon">
                </i>
              </button>
            </div>
            <div class="ai-button--lock-overlay" title="Anderer KI-Prozess läuft"></div>
          </div>
          <button type="button" title="Direkt im Text editieren" class="js-edit-text-projekt-content-block projekt-frame-icon-button">
            <i class="fas fa-pencil-alt">
            </i>
          </button>
          <div class="ai-button-wrapper">
            <div class="ai-button-wrapper--inner">
              <div class="dropdown-menu-container js-dropdown-menu">
                <div class="js-dropdown-menu-toggle">
                  <button type="button" title="Text per AI umgestalten" class="projekt-frame-icon-button">
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
          <button title="Editor-Menü öffnen" class="projekt-frame-icon-button js-html-edit-content-block">
            <i class="fas fa-edit">
            </i>
          </button>
          <button title="Auf vorherige Version zurücksetzen" disabled class="projekt-frame-icon-button js-content-block-reset-to-prev-version">
            <i class="fa fa-arrow-rotate-left fa-undo">
            </i>
          </button>
          <button type="button" title="Inhaltsblock löschen" class="js-delete-projekt-content-block -delete projekt-frame-icon-button">
            <i class="fas fa-trash-alt">
            </i>
          </button>

        </div>

        <button
          class="projekt-frame-icon-button projekt-content-block--move-button js-dnd-handle"
          title="Inhaltsbock verschieben"
        >
          <i class="fas fa-up-down-left-right"></i>
        </button>
      </div>

      <div class="add-new-content-block-section js-show-content-block-templates-section">
        <button
          type="button"
          class="-transparent-round-icon-button projekt-frame-icon-button js-show-content-block-templates add-new-content-block-button"
          title="Neuen Inhaltsblock hinzufügen"
        >
          <i class="fas fa-plus"></i>
        </button>

        <div class="add-new-content-block-content js-show-content-block-templates-content">
        </div>
      </div>
    </div>
  `.trim()
}

export function newContentBlockButtonSectionHtml() {
  return `
  <div class="js-projekt-content-block-edit-section projekt-content-block-edit-section projekt-content-block-wrapper">
  <div class="projekt-content-block--additional">
    <div class="add-new-content-block-section js-show-content-block-templates-section">
      <button
        type="button"
        class="projekt-frame-icon-button js-show-content-block-templates add-new-content-block-button add-intial-content-block-button"
        title="Neuen Inhaltsblock hinzufügen"
      >
        <i class="fas fa-plus"></i>
      </button>

      <div class="add-new-content-block-content js-show-content-block-templates-content">
      </div>
    </div>
  </div>
</div>
  `.trim()
}

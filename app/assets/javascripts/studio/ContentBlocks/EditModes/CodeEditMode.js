App.Studio.ContentBlocks.CodeEditMode = {
  initialized: false,
  aceInstances: {},
  modalContentBlockWrapper: null,

  initialize() {
    this.initEventListeners();
    // Set Ace editor worker path
    ace.config.set("workerPath", "https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12");
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-site-code-editor-save", this.handleModalSave.bind(this));
    $document.on("click", ".js-site-code-editor-cancel", this.handleModalCancel.bind(this));
  },

  isCompactContext(contentBlockWrapper) {
    return !!contentBlockWrapper.closest("aside, .sidebar, footer");
  },

  enterCodeEditMode(e) {
    const { contentBlockWrapper, contentBlock } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);

    App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);

    this.switchToCodeEditMode(contentBlockWrapper);
  },

  switchToCodeEditMode(contentBlockWrapper) {
    const targetHeight = contentBlockWrapper.offsetHeight;
    contentBlockWrapper.dataset.editMode = 'code';
    this.showCodeEditModeControls(contentBlockWrapper);
    this.createAndShowEditor(contentBlockWrapper, targetHeight);
  },

  showCodeEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.add('-code-edit-mode', '-in-edit-mode');
  },

  hideCodeEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.remove('-code-edit-mode', '-in-edit-mode');
  },

  getEditorContainer(contentBlockWrapper) {
    const innerContainer = contentBlockWrapper.querySelector('.custom-content-block-wrapper--inner');
    const searchContainer = innerContainer || contentBlockWrapper;
    return searchContainer.querySelector('.js-code-editor-container');
  },

  getEditorName(contentBlockWrapper) {
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const draftIndex = contentBlockWrapper.dataset.draftIndex;
    return `code-editor-${contentBlockId || draftIndex || 'new'}`;
  },

  createAndShowEditor(contentBlockWrapper, targetHeight) {
    this.removeEditor(contentBlockWrapper);

    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    const currentHTML = App.Studio.utils.resetMapEmbeds(contentBlock.innerHTML.trim());

    if (this.isCompactContext(contentBlockWrapper)) {
      this.createAndShowEditorInModal(contentBlockWrapper, currentHTML);
      return
    }

    const editorContainer = document.createElement('div');
    editorContainer.className = 'code-editor-container js-code-editor-container js-studio-hide-on-preview';

    const textarea = document.createElement('textarea');
    textarea.className = 'code-editor-textarea';
    editorContainer.appendChild(textarea);

    const innerContainer = contentBlockWrapper.querySelector('.custom-content-block-wrapper--inner');
    const insertionContainer = innerContainer || contentBlockWrapper;

    const toolbarAnchor = insertionContainer.querySelector('.js-content-block--toolbar-anchor');
    if (toolbarAnchor) {
      toolbarAnchor.insertAdjacentElement('afterend', editorContainer);
    } else {
      insertionContainer.appendChild(editorContainer);
    }

    const editor = this.setupAceEditor(contentBlockWrapper, textarea, currentHTML, targetHeight);

    setTimeout(() => { editor.focus(); }, 100);
  },

  getSectionLabel(contentBlockWrapper) {
    if (contentBlockWrapper.closest("aside, .sidebar")) return "Sidebar";
    if (contentBlockWrapper.closest("footer")) return "Footer";
    return null;
  },

  createAndShowEditorInModal(contentBlockWrapper, currentHTML) {
    this.modalContentBlockWrapper = contentBlockWrapper;

    const sectionLabel = this.getSectionLabel(contentBlockWrapper);
    const titleEl = document.querySelector(".js-site-code-editor-modal-title");
    if (titleEl && sectionLabel) {
      titleEl.textContent = "Code-Editor für " + sectionLabel + "-Bereich";
    }

    const modalContainer = document.querySelector(".js-site-code-editor-container");
    modalContainer.innerHTML = "";

    const textarea = document.createElement("textarea");
    textarea.className = "code-editor-textarea";
    modalContainer.appendChild(textarea);

    const editor = this.setupAceEditor(contentBlockWrapper, textarea, currentHTML);

    App.SharedModal.open("siteCodeEditorModal");

    setTimeout(() => {
      editor.resize();
      editor.focus();
    }, 100);
  },

  setupAceEditor(contentBlockWrapper, textarea, currentHTML = '', targetHeight = null) {
    const editorName = this.getEditorName(contentBlockWrapper);
    let editor = this.aceInstances[editorName];

    if (!editor) {
      editor = ace.edit(textarea);
      this.aceInstances[editorName] = editor;

      editor.setFontSize(14);
      editor.session.setMode("ace/mode/html");
      editor.setTheme("ace/theme/textmate");
      editor.session.setUseWrapMode(true);

      if (!targetHeight) {
        editor.session.on('change', () => {
          this.resizeEditorOnContentChange(editor);
        });
      }
    }

    const formattedHTML = App.Studio.utils.formatHTML(currentHTML);
    editor.setValue(formattedHTML, -1); // -1 moves cursor to start

    if (targetHeight) {
      this.setEditorHeight(editor, targetHeight);
    } else {
      this.resizeEditorOnContentChange(editor);
    }

    return editor;
  },

  setEditorHeight(editor, height) {
    editor.container.style.height = height + "px";
    editor.resize();
  },

  resizeEditorOnContentChange(editor) {
    const lineHeight = 20;
    const lines = editor.session.getLength();
    const minHeight = 300;
    const newHeight = Math.max(lines * lineHeight, minHeight);
    editor.container.style.height = newHeight + "px";
    editor.resize();
  },

  getEditor(contentBlockWrapper) {
    const editorName = this.getEditorName(contentBlockWrapper);
    return this.aceInstances[editorName];
  },

  removeEditor(contentBlockWrapper) {
    const editorContainer = this.getEditorContainer(contentBlockWrapper);
    if (editorContainer) {
      editorContainer.remove();
    }

    const modalContainer = document.querySelector(".js-site-code-editor-container");
    if (modalContainer) {
      modalContainer.innerHTML = "";
    }

    // Clean up ace instance
    const editorName = this.getEditorName(contentBlockWrapper);
    const editor = this.aceInstances[editorName];
    if (editor) {
      editor.destroy();
      delete this.aceInstances[editorName];
    }
  },

  updateContentBlockFromEditor(contentBlockWrapper) {
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    const editor = this.getEditor(contentBlockWrapper);

    if (editor) {
      const content = editor.getValue().trim();
      const htmlValidation = App.Studio.utils.validateHTML(content);

      if (htmlValidation.isValid) {
        contentBlock.innerHTML = App.Studio.utils.sanitizeAdminHtml(content);
      }
    }
  },


  exitCodeEditMode(contentBlockWrapper, restoreContent = false, { applyEditorContent = true } = {}) {
    if (restoreContent) {
      const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
      App.Studio.ContentBlocks.DraftStore.restorePreviousVersion(contentBlock);
    } else if (applyEditorContent) {
      this.updateContentBlockFromEditor(contentBlockWrapper);
    }

    this.removeEditor(contentBlockWrapper);
    this.hideCodeEditModeControls(contentBlockWrapper);
    contentBlockWrapper.dataset.editMode = '';

    if (this.modalContentBlockWrapper === contentBlockWrapper) {
      App.SharedModal.closeById("siteCodeEditorModal");
      this.modalContentBlockWrapper = null;
    }

    App.Studio.ContentBlocks.DomHelpers.scrollToContentBlockTop(contentBlockWrapper);
  },

  cancelCodeEditMode(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    this.exitCodeEditMode(contentBlockWrapper, true);
  },

  handleModalSave() {
    const contentBlockWrapper = this.modalContentBlockWrapper;
    if (!contentBlockWrapper) return

    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    const editor = this.getEditor(contentBlockWrapper);
    if (!editor) return

    const content = editor.getValue().trim();
    const htmlValidation = App.Studio.utils.validateHTML(content);

    if (!htmlValidation.isValid) {
      const errorMessage = htmlValidation.issues ? htmlValidation.issues.join('\n') : htmlValidation.message;
      alert(`HTML Validierung fehlgeschlagen:\n${errorMessage}`);
      return
    }

    App.Studio.ContentBlocks.Crud.updateContentBlock(contentBlock, content);

    this.exitCodeEditMode(contentBlockWrapper, false, { applyEditorContent: false });
  },

  handleModalCancel() {
    const contentBlockWrapper = this.modalContentBlockWrapper;
    if (!contentBlockWrapper) return

    this.exitCodeEditMode(contentBlockWrapper, true);
  },

  saveContentBlockAndExit(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);

    const editor = this.getEditor(contentBlockWrapper);
    if (!editor) {
      console.error('No editor found for content block');
      return;
    }

    const content = editor.getValue().trim();
    const htmlValidation = App.Studio.utils.validateHTML(content);

    if (!htmlValidation.isValid) {
      const errorMessage = htmlValidation.issues ? htmlValidation.issues.join('\n') : htmlValidation.message;
      alert(`HTML Validierung fehlgeschlagen:\n${errorMessage}`);
      return;
    }

    // App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)

    App.Studio.ContentBlocks.Crud.updateContentBlock(
      contentBlock,
      content
    );

    this.exitCodeEditMode(contentBlockWrapper, false, { applyEditorContent: false });

  },

  showSuccessMessage(message) {
    alert(message);
  },

  showErrorMessage(message) {
    alert(message);
  }
};

ProjektStudio.ContentBlock.CodeEditMode = {
  initialized: false,
  aceInstances: {},

  initialize() {
    this.initEventListeners();
    // Set Ace editor worker path
    ace.config.set("workerPath", "https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12");
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-enter-code-edit-mode", this.enterCodeEditMode.bind(this));
    $document.on("click", ".js-save-edit-code-projekt-content-block", this.saveContentBlockAndExit.bind(this));
    $document.on("click", ".js-projekt-content-block--code-edit-cancel", this.cancelCodeEditMode.bind(this));
  },

  enterCodeEditMode(e) {
    const { contentBlockWrapper, contentBlock } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    ProjektStudio.ContentBlock.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);

    this.switchToCodeEditMode(contentBlockWrapper);
  },

  switchToCodeEditMode(contentBlockWrapper) {
    this.showCodeEditModeControls(contentBlockWrapper);
    this.createAndShowEditor(contentBlockWrapper);
  },

  showCodeEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.add('-code-edit-mode', '-in-edit-mode');
    ProjektStudio.ContentBlock.DomHelpers.moveMarginToWrapper(contentBlockWrapper);
  },

  hideCodeEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.remove('-code-edit-mode', '-in-edit-mode');
  },

  getEditorContainer(contentBlockWrapper) {
    const relativeContainer = contentBlockWrapper.querySelector('.relative');
    const searchContainer = relativeContainer || contentBlockWrapper;
    return searchContainer.querySelector('.js-code-editor-container');
  },

  getEditorName(contentBlockWrapper) {
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const draftIndex = contentBlockWrapper.dataset.draftIndex;
    return `code-editor-${contentBlockId || draftIndex || 'new'}`;
  },

  createAndShowEditor(contentBlockWrapper) {
    this.removeEditor(contentBlockWrapper);

    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);
    const currentHTML = contentBlock.innerHTML.trim();

    const editorContainer = document.createElement('div');
    editorContainer.className = 'code-editor-container js-code-editor-container';

    const textarea = document.createElement('textarea');
    textarea.className = 'code-editor-textarea';
    editorContainer.appendChild(textarea);

    const relativeContainer = contentBlockWrapper.querySelector('.relative');
    if (!relativeContainer) return;

    const toolsets = relativeContainer.querySelector('.projekt-content-block--toolsets');
    if (toolsets) {
      relativeContainer.insertBefore(editorContainer, toolsets);
    } else {
      relativeContainer.appendChild(editorContainer);
    }

    const editor = this.setupAceEditor(contentBlockWrapper, textarea, currentHTML);

    setTimeout(() => { editor.focus(); }, 100);
  },

  setupAceEditor(contentBlockWrapper, textarea, currentHTML = '') {
    const editorName = this.getEditorName(contentBlockWrapper);
    let editor = this.aceInstances[editorName];

    if (!editor) {
      editor = ace.edit(textarea);
      this.aceInstances[editorName] = editor;

      editor.setFontSize(14);
      editor.session.setMode("ace/mode/html");
      editor.setTheme("ace/theme/textmate");
      editor.session.setUseWrapMode(true);

      editor.session.on('change', () => {
        this.resizeEditorOnContentChange(editor);
      });
    }

    const formattedHTML = ProjektStudio.utils.formatHTML(currentHTML);
    editor.setValue(formattedHTML, -1); // -1 moves cursor to start
    this.resizeEditorOnContentChange(editor);

    return editor;
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

    // Clean up ace instance
    const editorName = this.getEditorName(contentBlockWrapper);
    const editor = this.aceInstances[editorName];
    if (editor) {
      editor.destroy();
      delete this.aceInstances[editorName];
    }
  },

  exitCodeEditMode(contentBlockWrapper) {
    this.removeEditor(contentBlockWrapper);
    this.hideCodeEditModeControls(contentBlockWrapper);

    setTimeout(() => {
      contentBlockWrapper.scrollIntoView({
        block: "center", inline: "nearest"
      })
    }, 0)
  },

  cancelCodeEditMode(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    if (contentBlockWrapper) {
      const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);
      ProjektStudio.ContentBlock.DraftStore.restorePreviousVersion(contentBlock);
    }

    this.exitCodeEditMode(contentBlockWrapper);
  },

  saveContentBlockAndExit(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);

    const editor = this.getEditor(contentBlockWrapper);
    if (!editor) {
      console.error('No editor found for content block');
      return;
    }

    const content = editor.getValue().trim();
    const htmlValidation = ProjektStudio.utils.validateHTML(content);

    if (!htmlValidation.isValid) {
      const errorMessage = htmlValidation.issues ? htmlValidation.issues.join('\n') : htmlValidation.message;
      alert(`HTML Validierung fehlgeschlagen:\n${errorMessage}`);
      return;
    }

    contentBlock.innerHTML = content;
    // ProjektStudio.ContentBlock.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)

    ProjektStudio.ContentBlock.Crud.updateContentBlock(
      contentBlock,
      content
    );

    this.exitCodeEditMode(contentBlockWrapper);

  },

  showSuccessMessage(message) {
    alert(message);
  },

  showErrorMessage(message) {
    alert(message);
  }
};

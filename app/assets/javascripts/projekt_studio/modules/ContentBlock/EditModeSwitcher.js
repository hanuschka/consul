App.ContentBlockEditor.EditModeSwitcher = {
  initialize() {
    this.initEventListeners();
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-edit-text-content-block", this.handleSimpleEditClick.bind(this));
    $document.on("click", ".js-content-block-enter-ai-edit-mode", this.handleAiEditClick.bind(this));
    $document.on("click", ".js-content-block-enter-code-edit-mode", this.handleCodeEditClick.bind(this));
    $document.on("click", ".js-html-edit-content-block", this.handleHtmlEditClick.bind(this));
  },

  getCurrentMode(contentBlockWrapper) {
    return contentBlockWrapper.dataset.editMode || '';
  },

  handleSimpleEditClick(e) {
    const { contentBlockWrapper } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(e.target);
    const currentMode = this.getCurrentMode(contentBlockWrapper);

    if (currentMode === 'simple') {
      return;
    }

    e.stopImmediatePropagation();

    if (currentMode) {
      this.exitCurrentMode(contentBlockWrapper, currentMode);
    } else {
      this.storeDraft(contentBlockWrapper);
    }

    App.ContentBlockEditor.SimpleEditMode.switchToSimpleEditMode(contentBlockWrapper);
  },

  handleAiEditClick(e) {
    const { contentBlockWrapper } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(e.target);
    const currentMode = this.getCurrentMode(contentBlockWrapper);

    if (currentMode === 'ai') {
      return;
    }

    e.stopImmediatePropagation();

    if (currentMode) {
      this.exitCurrentMode(contentBlockWrapper, currentMode);
    } else {
      this.storeDraft(contentBlockWrapper);
    }

    App.ContentBlockEditor.AiEditMode.switchToAiEditMode(contentBlockWrapper);
  },

  handleCodeEditClick(e) {
    const { contentBlockWrapper } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(e.target);
    const currentMode = this.getCurrentMode(contentBlockWrapper);

    if (currentMode === 'code') {
      return;
    }

    e.stopImmediatePropagation();

    if (currentMode) {
      this.exitCurrentMode(contentBlockWrapper, currentMode);
    } else {
      this.storeDraft(contentBlockWrapper);
    }

    App.ContentBlockEditor.CodeEditMode.switchToCodeEditMode(contentBlockWrapper);
  },

  handleHtmlEditClick(e) {
    const { contentBlockWrapper } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(e.target);
    const currentMode = this.getCurrentMode(contentBlockWrapper);

    if (currentMode === 'html') {
      return;
    }

    e.stopImmediatePropagation();

    if (currentMode) {
      this.exitCurrentMode(contentBlockWrapper, currentMode);
    } else {
      this.storeDraft(contentBlockWrapper);
    }

    App.ContentBlockEditor.CKEditorMode.switchToHtmlEditMode(contentBlockWrapper);
  },

  storeDraft(contentBlockWrapper) {
    const contentBlock = App.ContentBlockEditor.DomHelpers.getContentBlock(contentBlockWrapper);
    App.ContentBlockEditor.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);
  },

  exitCurrentMode(contentBlockWrapper, currentMode) {
    switch (currentMode) {
      case 'simple':
        App.ContentBlockEditor.SimpleEditMode.exitSimpleEditMode(contentBlockWrapper, false);
        break;
      case 'ai':
        App.ContentBlockEditor.AiEditMode.exitAiEditMode(contentBlockWrapper, false);
        break;
      case 'code':
        App.ContentBlockEditor.CodeEditMode.exitCodeEditMode(contentBlockWrapper, false);
        break;
      case 'html':
        App.ContentBlockEditor.CKEditorMode.exitHtmlEditMode(contentBlockWrapper, false);
        break;
    }
  }
};

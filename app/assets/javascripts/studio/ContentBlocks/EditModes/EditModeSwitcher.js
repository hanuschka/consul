App.Studio.ContentBlocks.EditModeSwitcher = {
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
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
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

    App.Studio.ContentBlocks.SimpleEditMode.switchToSimpleEditMode(contentBlockWrapper);
  },

  handleAiEditClick(e) {
    if (!App.Studio.Projekt.config.aiAvailable) return

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
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

    App.Studio.ContentBlocks.AiEditMode.switchToAiEditMode(contentBlockWrapper);
  },

  handleCodeEditClick(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
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

    App.Studio.ContentBlocks.CodeEditMode.switchToCodeEditMode(contentBlockWrapper);
  },

  handleHtmlEditClick(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
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

    App.Studio.ContentBlocks.CKEditorMode.switchToHtmlEditMode(contentBlockWrapper);
  },

  storeDraft(contentBlockWrapper) {
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);
  },

  exitCurrentMode(contentBlockWrapper, currentMode) {
    switch (currentMode) {
      case 'simple':
        App.Studio.ContentBlocks.SimpleEditMode.exitSimpleEditMode(contentBlockWrapper, false);
        break;
      case 'ai':
        App.Studio.ContentBlocks.AiEditMode.exitAiEditMode(contentBlockWrapper, false);
        break;
      case 'code':
        App.Studio.ContentBlocks.CodeEditMode.exitCodeEditMode(contentBlockWrapper, false);
        break;
      case 'html':
        App.Studio.ContentBlocks.CKEditorMode.exitHtmlEditMode(contentBlockWrapper, false);
        break;
    }
  }
};

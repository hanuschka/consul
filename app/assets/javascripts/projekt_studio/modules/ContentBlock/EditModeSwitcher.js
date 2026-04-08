ProjektStudio.ContentBlock.EditModeSwitcher = {
  initialize() {
    this.initEventListeners();
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-edit-text-projekt-content-block", this.handleSimpleEditClick.bind(this));
    $document.on("click", ".js-content-block-enter-ai-edit-mode", this.handleAiEditClick.bind(this));
    $document.on("click", ".js-content-block-enter-code-edit-mode", this.handleCodeEditClick.bind(this));
    $document.on("click", ".js-html-edit-content-block", this.handleHtmlEditClick.bind(this));
  },

  getCurrentMode(contentBlockWrapper) {
    return contentBlockWrapper.dataset.editMode || '';
  },

  handleSimpleEditClick(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
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

    ProjektStudio.ContentBlock.SimpleEditMode.switchToSimpleEditMode(contentBlockWrapper);
  },

  handleAiEditClick(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
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

    ProjektStudio.ContentBlock.AiEditMode.switchToAiEditMode(contentBlockWrapper);
  },

  handleCodeEditClick(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
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

    ProjektStudio.ContentBlock.CodeEditMode.switchToCodeEditMode(contentBlockWrapper);
  },

  handleHtmlEditClick(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
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

    ProjektStudio.ContentBlock.CKEditorMode.switchToHtmlEditMode(contentBlockWrapper);
  },

  storeDraft(contentBlockWrapper) {
    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);
    ProjektStudio.ContentBlock.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);
  },

  exitCurrentMode(contentBlockWrapper, currentMode) {
    switch (currentMode) {
      case 'simple':
        ProjektStudio.ContentBlock.SimpleEditMode.exitSimpleEditMode(contentBlockWrapper, false);
        break;
      case 'ai':
        ProjektStudio.ContentBlock.AiEditMode.exitAiEditMode(contentBlockWrapper, false);
        break;
      case 'code':
        ProjektStudio.ContentBlock.CodeEditMode.exitCodeEditMode(contentBlockWrapper, false);
        break;
      case 'html':
        ProjektStudio.ContentBlock.CKEditorMode.exitHtmlEditMode(contentBlockWrapper, false);
        break;
    }
  }
};

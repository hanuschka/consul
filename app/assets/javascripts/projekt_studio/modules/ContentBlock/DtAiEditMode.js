App.ContentBlockEditor.DtAiEditMode = {
  initialize() {
    const $document = $(document);
    $document.on("click", ".js-content-block--regenerate", this.handleRegenerateContentBlock.bind(this));
    $document.on("click", ".js-content-block--ai-edit", this.handleEnterAiEditMode.bind(this));
    $document.on("click", ".js-content-block--ai-edit-cancel", this.handleCancelAiEditMode.bind(this));
  },

  handleEnterAiEditMode(e) {
    const contentBlockWrapper = App.ContentBlockEditor.DomHelpers.getParentContentBlockWrapper(e.target)
    this.enterAiEditMode(contentBlockWrapper)
  },

  handleRegenerateContentBlock(e) {
    const contentBlockWrapper = App.ContentBlockEditor.DomHelpers.getParentContentBlockWrapper(e.target)
    this.regenerateContentBlock(contentBlockWrapper, e.currentTarget.dataset.regenerateType)
  },

  handleCancelAiEditMode(e) {
    const { contentBlockWrapper, contentBlock } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(e.target);
    this.cancelAiEditMode(contentBlockWrapper, contentBlock)
  },

  enterAiEditMode(contentBlockWrapper) {
    this.cancelAllLoadStates();

    contentBlockWrapper.classList.add("-ai-edit-mode");
    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block");

    ProjektStudio.utils.sendMessageToDtParentFrame("aiEditContentBlock", {
      content_block_id: contentBlockWrapper.dataset.contentBlockId,
      html: contentBlock.innerHTML
    })
  },

  regenerateContentBlock(contentBlockWrapper, regenerateType) {
    this.cancelAllLoadStates();

    contentBlockWrapper.classList.add("-loading");

    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block");
    const contentBlockHTML = contentBlock.innerHTML;

    App.ContentBlockEditor.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper)

    ProjektStudio.utils.sendMessageToDtParentFrame("regenerateContentBlock", {
      regenerate_type: regenerateType,
      content_block_id: contentBlockWrapper.dataset.contentBlockId,
      html: contentBlockHTML
    })
  },

  toggleLockContentBlockEdit(contentBlockId, locked) {
    const contentBlockWrapper = document.querySelector(`.js-content-block-wrapper[data-content-block-id='${contentBlockId}']`)
    const controlls = contentBlockWrapper.querySelector(".js-content-block-edit-main-controlls")

    const title = locked ? "Edit is locked while ai process is running" : ""
    controlls.title = title

    const buttons = controlls.querySelectorAll("button")

    buttons.forEach((button) => {
      if (locked) {
        button.dataset.originalTitle = button.title
      }

      const buttonTitle = locked ? "Edit is locked while ai process is running" : button.dataset.originalTitle

      button.disabled = locked
      button.title = buttonTitle
    })
  },

  cancelAllLoadStates() {
    $('.js-content-block-wrapper.-loading').removeClass('-loading');
    $('.js-content-block-wrapper.-ai-edit-mode').removeClass('-ai-edit-mode');
  },

  updateContentBlockOnUi(params) {
    const contentBlockWrapper = App.ContentBlockEditor.DomHelpers.getContentBlockSectionForId(params.content_block_id)
    const contentBlock = contentBlockWrapper.querySelector('.projekt-content-block')

    App.ContentBlockEditor.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper)

    contentBlock.innerHTML = ProjektStudio.utils.sanitizeAdminHtml(params.html)

    App.ContentBlockEditor.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)

    contentBlockWrapper
      .classList
      .remove('-loading')

    contentBlockWrapper
      .classList
      .remove("-ai-edit-mode")
  },

  cancelAiEditMode(contentBlockWrapper, contentBlock) {
    App.ContentBlockEditor.DraftStore.restorePreviousVersion(contentBlock);

    contentBlockWrapper.classList.remove("-ai-edit-mode")
  }
};

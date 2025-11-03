ProjektStudio.ContentBlock.DraftStore = {
  initialize() {
    const $document = $(document);
    $document.on("click", ".js-content-block-reset-to-prev-version", this.handleResetToPreviousVersion.bind(this));
  },

  handleResetToPreviousVersion(e) {
    const { contentBlock, contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
    this.resetContentBlockToPreviousVersion(contentBlockWrapper, contentBlock)
  },

  storePreviousVersion(contentBlock, contentBlockWrapper) {
    contentBlock.dataset.previousContentBlockHtml = contentBlock.innerHTML.trim();
    const returnToPrevButton = contentBlockWrapper.querySelector(".js-content-block-reset-to-prev-version")

    returnToPrevButton.disabled = false
  },

  resetPreviousVersion(contentBlock, contentBlockWrapper) {
    contentBlock.dataset.previousContentBlockHtml = null;
    contentBlockWrapper.scrollIntoView({block: "center"});
    const returnToPrevButton = contentBlockWrapper.querySelector(".js-content-block-reset-to-prev-version")

    returnToPrevButton.disabled = true
  },

  restorePreviousVersion(contentBlock) {
    if (contentBlock && contentBlock.dataset.previousContentBlockHtml) {
      contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
      $(contentBlock).foundation();
      App.ImageGallery.initialize();
    }
  },

  resetContentBlockToPreviousVersion(contentBlockWrapper, contentBlock) {
    const resetConfirmed = confirm("Möchten Sie die letzte Änderung wirklich zurücksetzen?")

    if (resetConfirmed) {
      if (contentBlock.dataset.previousContentBlockHtml) {
        this.restorePreviousVersion(contentBlock);
        this.resetPreviousVersion(contentBlock, contentBlockWrapper)

        ProjektStudio.ContentBlock.Crud.updateContentBlock(
          contentBlock,
          contentBlockWrapper.dataset.contentBlockId,
          contentBlock.innerHTML.trim()
        )
      }
    }
  }
};


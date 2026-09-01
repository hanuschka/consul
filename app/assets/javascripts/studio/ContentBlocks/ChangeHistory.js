App.Studio.ContentBlocks.ChangeHistory = {
  versionHistory: {},

  MAX_VERSIONS: 10,

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-content-block-version-managment", this.goBackToPreviousVersion.bind(this));
  },

  updateButtonState(contentBlockWrapper) {
    const versionManagmentButton = contentBlockWrapper.querySelector(".js-content-block-version-managment");
    if (!versionManagmentButton) return;

    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const history = this.versionHistory[contentBlockId];

    versionManagmentButton.disabled = !history || history.length === 0;
  },

  saveVersion(contentBlock, contentBlockWrapper, contentToSave = null) {
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const currentContent =
      contentToSave !== null
        ? contentToSave
        : App.Studio.utils.resetMapEmbeds(contentBlock.innerHTML.trim());

    if (!this.versionHistory[contentBlockId]) {
      this.versionHistory[contentBlockId] = [];
    }

    const history = this.versionHistory[contentBlockId];

    if (history.length > 0 && history[history.length - 1] === currentContent) {
      this.updateButtonState(contentBlockWrapper);
      return false;
    }

    history.push(currentContent);

    if (history.length > this.MAX_VERSIONS) {
      // Remove oldest version
      history.shift();
    }

    this.updateButtonState(contentBlockWrapper);

    return true;
  },

  goBackToPreviousVersion(e) {
    const { contentBlock, contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    const resetConfirmed = confirm("Möchten Sie die letzte Änderung wirklich zurücksetzen?");

    if (resetConfirmed) {
      const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
      const history = this.versionHistory[contentBlockId];

      if (history && history.length > 0) {
        const previousVersion = history.pop();

        if (previousVersion) {
          contentBlock.innerHTML = previousVersion;

          App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)
        }
      }

      this.updateButtonState(contentBlockWrapper);

      App.Studio.ContentBlocks.Crud.updateContentBlock(
        contentBlock,
        contentBlock.innerHTML,
        { saveVersion: false }
      )
    }
  },
};


App.ContentBlockEditor.DraftStore = {
  storePreviousVersion(contentBlock) {
    contentBlock.dataset.previousContentBlockHtml = contentBlock.innerHTML.trim();
  },

  restorePreviousVersion(contentBlock) {
    if (contentBlock && contentBlock.dataset.previousContentBlockHtml) {
      contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
      contentBlock.dataset.previousContentBlockHtml = null;

      App.ContentBlockEditor.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)
    }
  }
};


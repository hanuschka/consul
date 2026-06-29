App.Studio.ContentBlocks.DraftStore = {
  storePreviousVersion(contentBlock) {
    contentBlock.dataset.previousContentBlockHtml =
      App.Studio.utils.resetMapEmbeds(contentBlock.innerHTML.trim());
  },

  restorePreviousVersion(contentBlock) {
    if (contentBlock && contentBlock.dataset.previousContentBlockHtml) {
      contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
      contentBlock.dataset.previousContentBlockHtml = null;

      App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)
      App.Studio.ContentBlocks.MapEmbed.hydrateIn(contentBlock)
    }
  }
};


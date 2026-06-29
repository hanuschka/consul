App.ContentBlockEditor.DraftStore = {
  storePreviousVersion(contentBlock) {
    contentBlock.dataset.previousContentBlockHtml =
      ProjektStudio.utils.resetMapEmbeds(contentBlock.innerHTML.trim());
  },

  restorePreviousVersion(contentBlock) {
    if (contentBlock && contentBlock.dataset.previousContentBlockHtml) {
      contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
      contentBlock.dataset.previousContentBlockHtml = null;

      App.ContentBlockEditor.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)
      App.ContentBlockEditor.MapEmbed.hydrateIn(contentBlock)
    }
  }
};


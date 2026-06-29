(function() {
  "use strict";

  App.Studio.Projekt.ProjektStart = {
    initialize() {
      const $document = $(document);

      $document.on("click", ".js-projekt-empty-block-trigger", this.createEmptyContentBlock.bind(this));
      $document.on("click", ".js-projekt-template-trigger", this.openTemplateSelector.bind(this));
    },

    createEmptyContentBlock(e) {
      e.preventDefault();

      App.Studio.ContentBlocks.Crud.addInitialEmptyContentBlock()
    },

    openTemplateSelector(e) {
      e.preventDefault();

      App.Studio.ContentBlocks.TemplateSelector.openDialog()
    }
  };
}).call(this);

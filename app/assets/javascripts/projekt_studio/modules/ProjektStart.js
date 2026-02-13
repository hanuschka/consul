(function() {
  "use strict";

  ProjektStudio.ProjektStart = {
    initialize() {
      const $document = $(document);

      $document.on("click", ".js-projekt-empty-block-trigger", this.createEmptyContentBlock.bind(this));
      $document.on("click", ".js-projekt-template-trigger", this.openTemplateSelector.bind(this));
    },

    createEmptyContentBlock(e) {
      e.preventDefault();

      ProjektStudio.ContentBlock.Crud.addInitialEmptyContentBlock()
    },

    openTemplateSelector(e) {
      e.preventDefault();

      ProjektStudio.ContentBlockTemplateSelector.openDialog()
    }
  };
}).call(this);

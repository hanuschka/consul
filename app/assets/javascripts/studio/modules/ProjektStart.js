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

      App.ContentBlockEditor.Crud.addInitialEmptyContentBlock()
    },

    openTemplateSelector(e) {
      e.preventDefault();

      App.ContentBlockEditor.TemplateSelector.openDialog()
    }
  };
}).call(this);

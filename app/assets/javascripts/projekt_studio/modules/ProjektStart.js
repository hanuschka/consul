(function() {
  "use strict";

  ProjektStudio.ProjektStart = {
    initialize() {
      const $document = $(document);

      $document.on("click", ".js-projekt-empty-block-trigger", this.handleEmptyBlockTrigger.bind(this));
      $document.on("click", ".js-projekt-template-trigger", this.handleTemplateTrigger.bind(this));
    },

    handleEmptyBlockTrigger(e) {
      e.preventDefault();
      this.createEmptyBlock();
    },

    handleTemplateTrigger(e) {
      e.preventDefault();
      this.openTemplateSelector();
    },

    createEmptyBlock() {
      const container = document.querySelector(".js-projekt-content-start-section");
      const emptyHtml = '<div class="row"><div class="small-12 columns"><p>Neuer Inhaltsblock</p></div></div>';
      const contentTemplateElement = document.createElement("div");
      contentTemplateElement.innerHTML = emptyHtml;

      ProjektStudio.ContentBlock.Crud.addContentBlockAfter = container;
      ProjektStudio.ContentBlock.Crud.createContentBlock(container, contentTemplateElement);
    },

    openTemplateSelector() {
      const container = document.querySelector(".js-projekt-content-start-section");

      if (container && $('#contentBlockTemplatesModal').length) {
        ProjektStudio.ContentBlock.Crud.addContentBlockAfter = container;
        $('#contentBlockTemplatesModal').foundation('open');
      } else {
        alert("Vorlagen-Dialog ist nicht verfügbar");
      }
    }
  };
}).call(this);

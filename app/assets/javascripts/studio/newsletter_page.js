(function() {
  "use strict";

  App.NewsletterContentBlockEditorPage = {
    initialize() {
      const contentBlocksList = this.getContentBlocksList();

      if (!contentBlocksList) return
      if (contentBlocksList.dataset.editorInitialized) return

      contentBlocksList.dataset.editorInitialized = "true";

      if (window.Turbo && window.Turbo.cache) {
        window.Turbo.cache.exemptPageFromCache();
      }

      this.loadConfig(contentBlocksList);
      this.wrapContentBlocks(contentBlocksList);
      this.initModules();

      App.ContentBlockEditor.DragDrop.initSortable();
      App.ContentBlockEditor.Crud.rerenderContentBlockListControls();
    },

    getContentBlocksList() {
      return document.querySelector(".js-newsletter-content-block-editor .js-content-blocks-list");
    },

    loadConfig(contentBlocksList) {
      ProjektStudio.config.defaultMarginBottom = parseInt(contentBlocksList.dataset.defaultMarginBottom);
    },

    wrapContentBlocks(contentBlocksList) {
      const blocks = contentBlocksList.querySelectorAll(".js-newsletter-content-block");

      blocks.forEach((block) => {
        const wrappedHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
          block.innerHTML,
          {
            contentBlockId: block.dataset.contentBlockId,
            context: "newsletter",
            updateUrl: block.dataset.updateUrl,
            destroyUrl: block.dataset.destroyUrl,
            updatePositionUrl: block.dataset.updatePositionUrl,
            aiUrl: block.dataset.aiUrl
          }
        );

        const wrappedElement = ProjektStudio.utils.htmlToDomElement(wrappedHTML).firstChild;

        if (block.style.marginBottom) {
          wrappedElement.style.marginBottom = block.style.marginBottom;
        }

        block.parentNode.replaceChild(wrappedElement, block);
      });
    },

    initModules() {
      if (window.newsletterContentBlockEditorModulesInitialized) return

      App.SharedModal.initialize();
      App.DropdownSelectMenuComponent.initialize();
      App.ContentBlockEditor.CreateWithAi.initialize();
      App.ContentBlockEditor.DragDrop.initialize();
      App.Studio.initContentBlockModules();
      App.ContentBlockEditor.SavedContentBlocks.initialize();

      window.newsletterContentBlockEditorModulesInitialized = true;
    }
  };

  document.addEventListener("turbo:load", () => {
    App.NewsletterContentBlockEditorPage.initialize();
  });

  if (document.readyState === "complete" || document.readyState === "interactive") {
    App.NewsletterContentBlockEditorPage.initialize();
  }
  else {
    document.addEventListener("DOMContentLoaded", () => {
      App.NewsletterContentBlockEditorPage.initialize();
    });
  }
}).call(this);

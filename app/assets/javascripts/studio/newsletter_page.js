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

      App.Studio.ContentBlocks.DragDrop.initSortable();
      App.Studio.ContentBlocks.Crud.rerenderContentBlockListControls();
    },

    getContentBlocksList() {
      return document.querySelector(".js-newsletter-content-block-editor .js-content-blocks-list");
    },

    loadConfig(contentBlocksList) {
      App.Studio.Projekt.config.defaultMarginBottom = parseInt(contentBlocksList.dataset.defaultMarginBottom);
      App.Studio.Projekt.config.aiAvailable = contentBlocksList.dataset.aiAvailable === "true";
      App.Studio.Projekt.config.generateUrl = contentBlocksList.dataset.generateUrl;
    },

    wrapContentBlocks(contentBlocksList) {
      const blocks = contentBlocksList.querySelectorAll(".js-newsletter-content-block");

      blocks.forEach((block) => {
        const wrappedHTML = App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock(
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

        const wrappedElement = App.Studio.utils.htmlToDomElement(wrappedHTML).firstChild;

        if (block.style.marginBottom) {
          wrappedElement.style.marginBottom = block.style.marginBottom;
        }

        block.parentNode.replaceChild(wrappedElement, block);
      });
    },

    initModules() {
      if (window.newsletterContentBlockEditorModulesInitialized) return

      App.SharedModal.initialize();
      App.ImageCropper.initialize();
      App.DropdownSelectMenuComponent.initialize();
      App.Studio.ContentBlocks.DragDrop.initialize();
      App.Studio.initContentBlockModules();

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

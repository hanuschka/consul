(function() {
  "use strict";

  App.Studio = {
    modulesInitialized: false,

    initContentBlockModules() {
      if (this.modulesInitialized) return
      if (typeof ProjektStudio === "undefined") return

      ProjektStudio.ContentBlock.ChangeHistory.initialize();
      ProjektStudio.ContentBlock.CKEditorMode.initialize();
      ProjektStudio.ContentBlock.EditModeSwitcher.initialize();
      ProjektStudio.ContentBlock.EditModeButtons.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.TextFormat.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.HeaderEdit.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.LinkEdit.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.ListEdit.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.ImageGalleryDialog.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.initialize();
      ProjektStudio.ContentBlock.AiEditMode.initialize();
      ProjektStudio.ContentBlock.CodeEditMode.initialize();
      ProjektStudio.ContentBlock.Copy.initialize();

      this.modulesInitialized = true;
    },

    SiteContentBlockEditor: {
      initialize() {
        if (typeof ProjektStudio === "undefined") return
        if (ProjektStudio.initialized) return
        if (!this.hasSiteContentBlocks()) return

        this.wrapContentBlocks();
        App.Studio.initContentBlockModules();
      },

      hasSiteContentBlocks() {
        return document.querySelectorAll(".js-site-content-block").length > 0;
      },

      wrapContentBlocks() {
        const siteBlocks = document.querySelectorAll(".js-site-content-block");

        siteBlocks.forEach((block) => {
          const contentBlockId = block.dataset.contentBlockId;
          const updateUrl = block.dataset.updateUrl;
          const aiUrl = block.dataset.aiUrl;

          const wrappedHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
            block.innerHTML,
            {
              contentBlockId: contentBlockId,
              context: "site",
              updateUrl: updateUrl,
              aiUrl: aiUrl
            }
          );

          const tempContainer = document.createElement("div");
          tempContainer.innerHTML = wrappedHTML;
          const wrappedElement = tempContainer.firstElementChild;

          block.parentNode.replaceChild(wrappedElement, block);

          $(wrappedElement).find("[data-tooltip]").foundation();
        });
      }
    }
  };
}).call(this);

(function() {
  "use strict";

  App.Studio = {
    modulesInitialized: false,

    initContentBlockModules() {
      if (this.modulesInitialized) return
      if (typeof ProjektStudio === "undefined") return

      $(document).on("click", ".js-clear-site-content-block", this.handleClearContentBlock.bind(this));

      ProjektStudio.ContentBlockTemplateSelector.initialize();
      ProjektStudio.ContentBlock.Crud.initialize();
      ProjektStudio.ContentBlock.ChangeHistory.initialize();
      ProjektStudio.ContentBlock.CKEditorMode.initialize();
      ProjektStudio.ContentBlock.EditModeSwitcher.initialize();
      ProjektStudio.ContentBlock.EditModeButtons.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.TextFormat.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.HeaderEdit.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.LinkEdit.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.ListEdit.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.FileManagerDialog.initialize();
      ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.initialize();
      ProjektStudio.ContentBlock.AiEditMode.initialize();
      ProjektStudio.ContentBlock.CodeEditMode.initialize();
      ProjektStudio.ContentBlock.Copy.initialize();

      this.modulesInitialized = true;
    },

    handleClearContentBlock(e) {
      const wrapper = ProjektStudio.ContentBlock.DomHelpers.getParentContentBlockWrapper(e.currentTarget);
      const confirmed = confirm("Soll der Inhalt dieses Blocks wirklich gelöscht werden?");

      if (!confirmed) return

      const currentMode = wrapper.dataset.editMode;

      if (currentMode) {
        ProjektStudio.ContentBlock.EditModeSwitcher.exitCurrentMode(wrapper, currentMode);
      }

      const contentBlock = wrapper.querySelector(".js-projekt-content-block");
      const emptyHtml = "<div><p></p></div>";

      ProjektStudio.ContentBlock.Crud.updateContentBlock(contentBlock, emptyHtml);
    },

    SiteContentBlockEditor: {
      initialize() {
        if (typeof ProjektStudio === "undefined") return
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
          const defaultContent = block.dataset.defaultContent;
          const toolbarPosition = block.dataset.toolbarPosition;

          const wrappedHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
            block.innerHTML,
            {
              contentBlockId: contentBlockId,
              context: "site",
              updateUrl: updateUrl,
              aiUrl: aiUrl,
              toolbarPosition: toolbarPosition
            }
          );

          const tempContainer = document.createElement("div");
          tempContainer.innerHTML = wrappedHTML;
          const wrappedElement = tempContainer.firstElementChild;

          if (defaultContent) {
            wrappedElement.dataset.defaultContent = defaultContent;
          }

          block.parentNode.replaceChild(wrappedElement, block);

          if (wrappedElement.closest("aside, .sidebar, footer")) {
            wrappedElement.classList.add("-compact-mode");
          }

          $(wrappedElement).foundation();

          App.ImageGallery.initialize();
        });
      }
    }
  };
}).call(this);


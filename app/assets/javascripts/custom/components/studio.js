(function() {
  "use strict";

  App.Studio = {
    initContentBlockModules() {
      // Window-level flag: survives re-evaluation of this pack (e.g. Turbo
      // re-running body scripts), preventing duplicate document-level
      // event bindings.
      if (window.studioContentBlockModulesInitialized) return
      if (typeof ProjektStudio === "undefined") return

      $(document).on("click", ".js-clear-site-content-block", this.handleClearContentBlock.bind(this));

      App.Tabs.initialize();
      App.ContentBlockEditor.TemplateSelector.initialize();
      App.ContentBlockEditor.Crud.initialize();
      App.ContentBlockEditor.MapEmbed.initialize();
      App.ContentBlockEditor.ChangeHistory.initialize();
      App.ContentBlockEditor.CKEditorMode.initialize();
      App.ContentBlockEditor.EditModeSwitcher.initialize();
      App.ContentBlockEditor.EditModeButtons.initialize();
      App.ContentBlockEditor.SimpleEditMode.initialize();
      App.ContentBlockEditor.SimpleEditMode.TextFormat.initialize();
      App.ContentBlockEditor.SimpleEditMode.HeaderEdit.initialize();
      App.ContentBlockEditor.SimpleEditMode.LinkEdit.initialize();
      App.ContentBlockEditor.SimpleEditMode.ListEdit.initialize();
      App.ContentBlockEditor.SimpleEditMode.FileManagerDialog.initialize();
      App.ContentBlockEditor.SimpleEditMode.ImageEdit.initialize();
      App.ContentBlockEditor.SimpleEditMode.MapEdit.initialize();
      App.ContentBlockEditor.SimpleEditMode.ImageAltEdit.initialize();
      App.ContentBlockEditor.AiEditMode.initialize();
      App.ContentBlockEditor.CodeEditMode.initialize();
      App.ContentBlockEditor.Copy.initialize();
      App.ContentBlockEditor.EmptyHintToggle.initialize();

      window.studioContentBlockModulesInitialized = true;
    },

    handleClearContentBlock(e) {
      const wrapper = App.ContentBlockEditor.DomHelpers.getParentContentBlockWrapper(e.currentTarget);
      const confirmed = confirm("Soll der Inhalt dieses Blocks wirklich gelöscht werden?");

      if (!confirmed) return

      const currentMode = wrapper.dataset.editMode;

      if (currentMode) {
        App.ContentBlockEditor.EditModeSwitcher.exitCurrentMode(wrapper, currentMode);
      }

      const contentBlock = wrapper.querySelector(".js-content-block");
      const emptyHtml = "<div><p></p></div>";

      App.ContentBlockEditor.Crud.updateContentBlock(contentBlock, emptyHtml);
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
          const emptyHint = this.detachEmptyHint(block);

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

          if (block.style.marginBottom) {
            wrappedElement.style.marginBottom = block.style.marginBottom;
          }

          block.parentNode.replaceChild(wrappedElement, block);

          if (emptyHint) {
            this.moveEmptyHintIntoWrapper(wrappedElement, emptyHint);
          }

          if (wrappedElement.closest("aside, .sidebar, footer")) {
            wrappedElement.classList.add("-compact-mode");
          }

          App.ContentBlockEditor.DomHelpers.reinitFoundationWidgets(wrappedElement);

          App.ImageGallery.initialize();
        });
      },

      detachEmptyHint(block) {
        const wrap = block.parentElement;

        if (!wrap) return null

        const hint = wrap.querySelector(".js-content-block-empty-hint");

        if (!hint || hint.parentElement !== wrap) return null

        hint.remove();

        return hint;
      },

      moveEmptyHintIntoWrapper(wrappedElement, hint) {
        const contentBlock = wrappedElement.querySelector(".js-content-block");

        if (!contentBlock) return

        contentBlock.insertAdjacentElement("beforebegin", hint);
      }
    }
  };
}).call(this);

(function() {
  "use strict";

  // This file is pulled into BOTH the studio pack and the application pack
  // (via require_tree ./custom). The studio pack creates App.Studio in
  // lib/studio_namespace.js / studio/main.js, but the application pack does
  // not, so guard the namespace here to avoid a top-level crash there.
  window.App = window.App || {};
  window.App.Studio = window.App.Studio || {};

  App.Studio.initContentBlockModules = function() {
    // Window-level flag: survives re-evaluation of this pack (e.g. Turbo
    // re-running body scripts), preventing duplicate document-level
    // event bindings.
    if (window.studioContentBlockModulesInitialized) return
    if (typeof App.Studio.Projekt === "undefined") return

    $(document).on("click", ".js-clear-site-content-block", this.handleClearContentBlock.bind(this));

    App.Tabs.initialize();
    App.Studio.ContentBlocks.TemplateSelector.initialize();
    App.Studio.ContentBlocks.CreateWithAi.initialize();
    App.Studio.ContentBlocks.SavedContentBlocks.initialize();
    App.Studio.ContentBlocks.Crud.initialize();
    App.Studio.ContentBlocks.MapEmbed.initialize();
    App.Studio.ContentBlocks.ChangeHistory.initialize();
    App.Studio.ContentBlocks.CKEditorMode.initialize();
    App.Studio.ContentBlocks.EditModeSwitcher.initialize();
    App.Studio.ContentBlocks.EditModeButtons.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.TextFormat.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.HeaderEdit.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.LinkEdit.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.ListEdit.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.MapEdit.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.MapSourceEdit.initialize();
    App.Studio.ContentBlocks.SimpleEditMode.ImageAltEdit.initialize();
    App.Studio.ContentBlocks.AiEditMode.initialize();
    App.Studio.ContentBlocks.CodeEditMode.initialize();
    App.Studio.ContentBlocks.Copy.initialize();
    App.Studio.ContentBlocks.EmptyHintToggle.initialize();

    window.studioContentBlockModulesInitialized = true;
  };

  App.Studio.handleClearContentBlock = function(e) {
    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(e.currentTarget);
    const confirmed = confirm("Soll der Inhalt dieses Blocks wirklich gelöscht werden?");

    if (!confirmed) return

    const currentMode = wrapper.dataset.editMode;

    if (currentMode) {
      App.Studio.ContentBlocks.EditModeSwitcher.exitCurrentMode(wrapper, currentMode);
    }

    const contentBlock = wrapper.querySelector(".js-content-block");
    const emptyHtml = "<div><p></p></div>";

    App.Studio.ContentBlocks.Crud.updateContentBlock(contentBlock, emptyHtml);
  };

  App.Studio.SiteContentBlockEditor = {
    initialize() {
      if (typeof App.Studio.Projekt === "undefined") return
      if (!this.hasSiteContentBlocks()) return

      this.loadConfig();
      this.wrapContentBlocks();
      App.Studio.initContentBlockModules();
    },

    loadConfig() {
      if (App.Studio.Projekt.isProjektPage()) return

      App.Studio.Projekt.config.aiAvailable = document.body.dataset.aiAvailable === "true";
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
        const generateUrl = block.dataset.generateUrl;
        const defaultContent = block.dataset.defaultContent;
        const toolbarPosition = block.dataset.toolbarPosition;
        const emptyHint = this.detachEmptyHint(block);

        const wrappedHTML = App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock(
          block.innerHTML,
          {
            contentBlockId: contentBlockId,
            context: "site",
            updateUrl: updateUrl,
            aiUrl: aiUrl,
            generateUrl: generateUrl,
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

        App.Studio.ContentBlocks.DomHelpers.reinitFoundationWidgets(wrappedElement);

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
  };
}).call(this);

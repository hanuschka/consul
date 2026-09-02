(function() {
  "use strict";
  App.Studio.PreviewMode = {
    initialize() {
      // Window-level flag: the admin topbar (and this module's button) exists
      // on non-projekt pages too, so this module self-initializes at pack
      // evaluation below instead of via App.Studio.Projekt.initialize() and
      // must not double-bind if the pack is evaluated again.
      if (window.studioPreviewModeInitialized) return

      window.studioPreviewModeInitialized = true;

      const $document = $(document);
      $document.on("click", ".js-studio-preview-mode-button", this.handleViewModeToggle.bind(this));
    },

    handleViewModeToggle(event) {
      event.preventDefault();

      const $clickedButton = $(event.currentTarget);
      const viewMode = $clickedButton.data("view-mode");

      if ($clickedButton.hasClass("button") && !$clickedButton.hasClass("hollow")) {
        return;
      }

      const $allViewModeButtons = $(".js-studio-preview-mode-button");

      $allViewModeButtons.removeClass("-selected").attr("aria-checked", "false");
      $clickedButton.addClass("-selected").attr("aria-checked", "true");

      if (viewMode === "user") {
        this.togglePreviewMode(true);
      } else {
        this.togglePreviewMode(false);
      }
    },

    togglePreviewMode(activated) {
      document.body.classList.toggle("-preview-mode", activated);

      const previewModeEnabled = document.body.classList.contains("-preview-mode");
      const sdgList = document.querySelector(".js-sidebar-card .js-sdg-goal-tag-list");
      const anyCheckedSDG = sdgList ? sdgList.querySelector("input:checked") : false;
      const sdgSidebarCard = sdgList ? sdgList.closest(".js-sidebar-card") : null;
      const categoriesList = document.querySelector(".js-sidebar-card .categories--simple-selector");
      const anyCheckedCategory = categoriesList ? categoriesList.querySelector(".js-add-tag-link.selected") : false;
      const categoriesSidebarCard = categoriesList ? categoriesList.closest(".js-sidebar-card") : null;
      const deactivatedPhases = document.querySelectorAll(".js-projekt-phase-tab.-deactivated");

      $(".js-sidebar-card-edit-link").toggle(!previewModeEnabled);
      $(".projekt-banner-edit-field--controlls").toggle(!previewModeEnabled);
      $(".js-projekt-footer-phase-tab--add-new").toggle(!previewModeEnabled);
      $(".js-content-block-ai-edit-popup").toggle(!previewModeEnabled);

      if (previewModeEnabled) {
        if (!anyCheckedSDG && sdgSidebarCard) {
          $(sdgSidebarCard).hide();
        }
        if (!anyCheckedCategory && categoriesSidebarCard) {
          $(categoriesSidebarCard).hide();
        }

        $(deactivatedPhases).hide();
      } else {
        if (sdgSidebarCard) {
          $(sdgSidebarCard).show();
        }
        if (categoriesSidebarCard) {
          $(categoriesSidebarCard).show();
        }

        $(deactivatedPhases).show();
      }

      this.toggleEmptyContentBlocks(previewModeEnabled);
    },

    toggleEmptyContentBlocks(previewModeEnabled) {
      if (previewModeEnabled) {
        const contentBlocks = document.querySelectorAll(".js-content-block");
        contentBlocks.forEach((block) => this.hideEmptyContentBlock(block));
      } else {
        document.querySelectorAll(".-hidden-by-preview").forEach((element) => {
          element.classList.remove("-hidden-by-preview");
          $(element).show();
        });
      }
    },

    hideEmptyContentBlock(block) {
      const hasContent = block.textContent.trim().length > 0 ||
        block.querySelector("img, iframe, video, embed, svg, canvas");

      if (hasContent) return;

      const sidebarCard = block.closest(".js-sidebar-card");
      const targetElement = sidebarCard || block;

      targetElement.classList.add("-hidden-by-preview");
      $(targetElement).hide();
    },
  };

  App.Studio.PreviewMode.initialize();
}).call(this);

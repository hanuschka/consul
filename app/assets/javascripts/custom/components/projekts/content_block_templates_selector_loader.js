(function() {
  "use strict";

  App.ContentBlockTemplatesSelector = {
    loaded: false,

    initialize() {},

    loadTemplatesContent() {
      if (this.loaded) return

      this.showSpinner();

      $.ajax({
        url: "/projekt_content_block_templates",
        method: "GET",
        dataType: "html",
        timeout: 7000
      })
        .then((html) => {
          this.loaded = true;

          this.handleLoadSuccess(html);
        })
        .catch(() => {
          this.handleLoadError();
        });
    },

    handleLoadSuccess(html) {
      this.hideSpinner();

      const $container = $(".js-projekt-content-block-templates-selector--inner");
      $container.html(html).show();

      this.reinitFoundationComponents($container);
    },

    reinitFoundationComponents($container) {
      this.storeOrbitHeights($container);
      $(document).foundation();
      this.restoreOrbitHeights($container);

      $container.find('[data-tabs]').on('change.zf.tabs', () => this.restoreOrbitHeights($container));
    },

    storeOrbitHeights($container) {
      $container.find(".orbit-container[style*='height']").each(function() {
        const height = $(this).css("height");
        $(this).attr("data-height", height);
      });
    },

    restoreOrbitHeights($container) {
      setTimeout(() => {
        $container.find(".orbit-container[data-height]").css("height", function() {
          return $(this).attr("data-height");
        });
      }, 50);
    },

    showSpinner() {
      $(".js-content-block-templates-spinner").show();
      $(".js-projekt-content-block-templates-selector--inner").hide();
    },

    hideSpinner() {
      $(".js-content-block-templates-spinner").hide();
    },

    handleLoadError() {
      this.hideSpinner();

      const $container = $(".js-projekt-content-block-templates-selector--inner");
      const fallbackTemplate = document.querySelector(".js-content-block-templates-fallback");

      if (!fallbackTemplate) return

      const fallbackContent = document.importNode(fallbackTemplate.content, true);
      $container.empty().append(fallbackContent).show();

      $(".js-content-block-templates-fallback-note").show();

      this.reinitFoundationComponents($container);
    }
  };
}).call(this);

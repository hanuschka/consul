(function() {
  "use strict";

  App.ContentBlockTemplatesSelector = {
    initialize() {
      this.loadTemplatesContent();
    },

    loadTemplatesContent() {
      const $container = $(".js-projekt-content-block-templates-selector--inner");

      if ($container.length === 0) {
        return;
      }

      $.ajax({
        url: "/projekt_content_block_templates",
        method: "GET",
        dataType: "html"
      })
        .then((html) => {
          this.handleLoadSuccess(html);
        })
        .catch(() => {
          this.handleLoadError();
        });
    },

    handleLoadSuccess(html) {
      const $container = $(".js-projekt-content-block-templates-selector--inner");
      $container.html(html);

      this.storeOrbitHeights($container)

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

    handleLoadError() {
      const $container = $(".js-projekt-content-block-templates-selector--inner");
      $container.html('<p style="text-align: center; padding: 40px; color: red;">Fehler beim Laden der Vorlagen. Bitte versuchen Sie es erneut.</p>');
    }
  };
}).call(this);

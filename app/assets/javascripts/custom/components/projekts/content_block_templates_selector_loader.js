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

      $(document).foundation();
    },

    handleLoadError() {
      const $container = $(".js-projekt-content-block-templates-selector--inner");
      $container.html('<p style="text-align: center; padding: 40px; color: red;">Fehler beim Laden der Vorlagen. Bitte versuchen Sie es erneut.</p>');
    }
  };
}).call(this);

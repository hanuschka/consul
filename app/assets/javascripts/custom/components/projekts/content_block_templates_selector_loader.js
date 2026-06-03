(function() {
  "use strict";

  App.ContentBlockTemplatesSelector = {
    cachedSections: {},
    activeSection: null,

    initialize() {},

    loadTemplatesContent(section) {
      const cacheKey = section || "default";

      if (this.cachedSections[cacheKey]) {
        this.restoreFromCache(cacheKey);
        return
      }

      this.showSpinner();

      const ajaxData = {};

      if (section) {
        ajaxData.section = section;
      }

      $.ajax({
        url: "/projekt_content_block_templates",
        method: "GET",
        dataType: "html",
        data: ajaxData,
        timeout: 7000
      })
        .then((html) => {
          this.handleLoadSuccess(html, cacheKey);
        })
        .catch(() => {
          this.handleLoadError();
        });
    },

    handleLoadSuccess(html, cacheKey) {
      this.hideSpinner();

      const $container = $(".js-content-block-templates-selector--inner");
      $container.html(html).show();

      this.reinitContentComponents($container);

      this.cachedSections[cacheKey] = $container.html();
      this.activeSection = cacheKey;
    },

    restoreFromCache(cacheKey) {
      if (this.activeSection === cacheKey) return

      this.hideSpinner();

      const $container = $(".js-content-block-templates-selector--inner");
      $container.html(this.cachedSections[cacheKey]).show();

      this.reinitContentComponents($container);
      this.activeSection = cacheKey;
    },

    reinitContentComponents($container) {
      this.storeOrbitHeights($container);
      App.ContentBlockEditor.DomHelpers.reinitFoundationWidgets(document);
      this.restoreOrbitHeights($container);

      $container.find('.js-tabs').on('tabs:changed', () => this.restoreOrbitHeights($container));
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
      $(".js-content-block-templates-selector--inner").hide();
    },

    hideSpinner() {
      $(".js-content-block-templates-spinner").hide();
    },

    handleLoadError() {
      this.hideSpinner();

      const $container = $(".js-content-block-templates-selector--inner");
      const fallbackTemplate = document.querySelector(".js-content-block-templates-fallback");

      if (!fallbackTemplate) return

      const fallbackContent = document.importNode(fallbackTemplate.content, true);
      $container.empty().append(fallbackContent).show();

      $(".js-content-block-templates-fallback-note").show();

      this.reinitContentComponents($container);
    }
  };
}).call(this);

(function() {
  "use strict";

  App.ContentBlockTemplatesSelector = {
    cachedSections: {},
    activeSection: null,
    lastRequestedSection: null,

    initialize() {
      $(document).on("click", ".js-content-block-templates-retry", this.handleRetry.bind(this));
    },

    getContainer() {
      return $(".js-content-block-templates-selector--inner");
    },

    getErrorElement() {
      return $(".js-content-block-templates-error");
    },

    handleRetry() {
      this.loadTemplatesContent(this.lastRequestedSection);
    },

    loadTemplatesContent(section) {
      const cacheKey = section || "default";

      this.lastRequestedSection = section;

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
        timeout: 20000
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

      const $container = this.getContainer();
      $container.html(html).show();

      this.reinitContentComponents($container);

      const isFallback = this.isFallbackContent($container);
      this.toggleFallbackNote(isFallback);

      if (!isFallback) {
        this.cachedSections[cacheKey] = $container.html();
      }

      this.activeSection = cacheKey;

      this.hydrateActivePanelMaps($container);
    },

    restoreFromCache(cacheKey) {
      if (this.activeSection === cacheKey) return

      this.hideSpinner();

      const $container = this.getContainer();
      $container.html(this.cachedSections[cacheKey]).show();

      this.reinitContentComponents($container);
      this.toggleFallbackNote(this.isFallbackContent($container));
      this.activeSection = cacheKey;

      this.hydrateActivePanelMaps($container);
    },

    isFallbackContent($container) {
      return $container.find(".js-content-block-templates-fallback-marker").length > 0
    },

    toggleFallbackNote(visible) {
      $(".js-content-block-templates-fallback-note").toggle(visible);
    },

    reinitContentComponents($container) {
      this.storeOrbitHeights($container);
      App.Studio.ContentBlocks.DomHelpers.reinitFoundationWidgets(document);
      this.restoreOrbitHeights($container);

      $container.find('.js-tabs').on('tabs:changed', () => this.handleTabsChanged($container));
    },

    handleTabsChanged($container) {
      this.restoreOrbitHeights($container);
      this.hydrateActivePanelMaps($container);
    },

    // Map templates mark their map region with a {{projekt_map}} placeholder.
    // Hydrate only the visible (active) tab panel so Leaflet initializes at the
    // real container size — a map built inside a hidden panel renders at 0x0.
    // Idempotent: embeds already hydrated (token gone) are skipped.
    hydrateActivePanelMaps($container) {
      const activePanel = $container.find(".shared-tabs-panel.is-active")[0];

      if (!activePanel) return

      App.Studio.ContentBlocks.MapEmbed.hydrateIn(activePanel);
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
      this.getErrorElement().hide();
      $(".js-content-block-templates-spinner").show();
      this.getContainer().hide();
    },

    hideSpinner() {
      $(".js-content-block-templates-spinner").hide();
    },

    handleLoadError() {
      this.hideSpinner();

      const $container = this.getContainer();
      const fallbackTemplate = document.querySelector(".js-content-block-templates-fallback");

      if (!fallbackTemplate) {
        this.getErrorElement().show();
        return
      }

      const fallbackContent = document.importNode(fallbackTemplate.content, true);
      $container.empty().append(fallbackContent).show();

      this.toggleFallbackNote(true);

      this.reinitContentComponents($container);
    }
  };
}).call(this);

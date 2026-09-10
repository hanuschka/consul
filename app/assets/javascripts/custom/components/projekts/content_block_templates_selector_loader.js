(function() {
  "use strict";

  const REQUEST_TIMEOUT_MS = 15000;
  const PREFETCH_TIMEOUT_MS = 2000;

  App.ContentBlockTemplatesSelector = {
    requests: {},
    activeSection: null,
    lastRequestedSection: null,

    initialize() {
      $(document).on("click", ".js-content-block-templates-retry", this.handleRetry.bind(this));

      this.schedulePrefetch();
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

    // The templates are ~320KB of live previews, too much to put in every page
    // an admin loads. Warming the default section once the page is idle keeps
    // that weight out of the document while still opening the dialog instantly.
    //
    // The selector shell sits in the global layout, so the trigger button is
    // what tells us this page can actually open it — without that check every
    // admin page view would fetch templates it will never show.
    schedulePrefetch() {
      if (document.querySelector(".js-show-content-block-templates") === null) return

      const warm = () => this.requestTemplates(this.defaultSection());

      if (window.requestIdleCallback) {
        window.requestIdleCallback(warm, { timeout: PREFETCH_TIMEOUT_MS });
        return
      }

      setTimeout(warm, PREFETCH_TIMEOUT_MS);
    },

    defaultSection() {
      const contentBlocksList = document.querySelector(".js-content-blocks-list");

      if (contentBlocksList && contentBlocksList.dataset.templateSection) {
        return contentBlocksList.dataset.templateSection
      }

      return "projekt_page"
    },

    // One in-flight request per section, reused as the cache once it resolves.
    // A rejected request is dropped so the retry button issues a fresh one.
    requestTemplates(section) {
      const cacheKey = section || "default";

      if (this.requests[cacheKey]) return this.requests[cacheKey]

      const ajaxData = {};

      if (section) {
        ajaxData.section = section;
      }

      const request = $.ajax({
        url: "/projekt_content_block_templates",
        method: "GET",
        dataType: "html",
        data: ajaxData,
        timeout: REQUEST_TIMEOUT_MS
      });

      request.fail(() => delete this.requests[cacheKey]);

      this.requests[cacheKey] = request;

      return request
    },

    isReady(cacheKey) {
      return Boolean(this.requests[cacheKey] && this.requests[cacheKey].state() === "resolved")
    },

    loadTemplatesContent(section) {
      const cacheKey = section || "default";

      this.lastRequestedSection = section;

      if (this.activeSection === cacheKey) return

      if (!this.isReady(cacheKey)) {
        this.showSpinner();
      }

      this.requestTemplates(section)
        .then((html) => this.renderTemplates(html, cacheKey))
        .catch(() => this.handleLoadError());
    },

    renderTemplates(html, cacheKey) {
      this.hideSpinner();

      const $container = this.getContainer();
      $container.html(html).show();

      this.reinitContentComponents($container);

      this.activeSection = cacheKey;

      this.hydrateActivePanelMaps($container);
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

      this.getContainer().hide();
      this.getErrorElement().show();
    }
  };
}).call(this);

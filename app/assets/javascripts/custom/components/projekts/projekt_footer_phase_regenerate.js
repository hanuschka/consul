(function() {
  "use strict";

  App.ProjektFooterPhaseRegenerate = {
    pollInterval: 4000,
    timers: {},
    rootSelector: ".js-projekt-footer-phase-regenerate",
    triggerSelector: ".js-projekt-footer-phase-regenerate-trigger",
    loadingSelector: ".js-projekt-footer-phase-regenerate-loading",
    contentSelector: ".js-projekt-footer-phase-regenerate-content",

    initialize() {
      const $document = $(document);

      $document.on("click", this.triggerSelector, this.handleStart.bind(this));

      this.startPollingForProcessing();
    },

    startPollingForProcessing() {
      $(this.rootSelector).each((_, root) => {
        const $root = $(root);
        const $loading = $root.find(this.loadingSelector);

        if (!$loading.is("[hidden]") && $loading.length) {
          this.schedulePoll($root);
        }
      });
    },

    handleStart(event) {
      event.preventDefault();

      const $trigger = $(event.currentTarget);
      const $root = $trigger.closest(this.rootSelector);

      if (!$root.length) return;
      if ($root.data("regenerating")) return

      const url = $trigger.attr("href") || $trigger.data("url");
      if (!url) return

      $root.data("regenerating", true);
      this.showLoading($root);

      App.Ajax
        .request({
          url: url,
          method: "POST",
          dataType: "json"
        })
        .then(() => this.schedulePoll($root))
        .catch(() => this.schedulePoll($root));
    },

    schedulePoll($root) {
      const statusUrl = $root.data("status-url");
      if (!statusUrl) return

      const key = this.timerKey($root);
      this.clearTimer(key);

      this.timers[key] = setTimeout(() => this.checkStatus($root), this.pollInterval);
    },

    checkStatus($root) {
      const statusUrl = $root.data("status-url");
      if (!statusUrl) return

      App.Ajax
        .request({
          url: statusUrl,
          method: "GET",
          dataType: "json"
        })
        .then((data) => this.handleStatusResponse($root, data))
        .catch(() => this.schedulePoll($root));
    },

    handleStatusResponse($root, data) {
      if (data.status === "completed" || data.status === "failed") {
        this.clearTimer(this.timerKey($root));
        window.location.reload();
        return
      }

      this.schedulePoll($root);
    },

    showLoading($root) {
      $root.find(this.contentSelector).attr("hidden", "hidden");
      $root.find(this.loadingSelector).removeAttr("hidden");
    },

    timerKey($root) {
      return $root.data("phase-id") || $root.attr("id") || Math.random();
    },

    clearTimer(key) {
      if (this.timers[key]) {
        clearTimeout(this.timers[key]);
        delete this.timers[key];
      }
    }
  };
}).call(this);

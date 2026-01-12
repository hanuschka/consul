(function() {
  "use strict";

  App.AiStatsRefresh = {
    poolingTimeout: 7000,

    initialize: function() {
      this.attachEventListeners();
      this.checkInitialStatus();
    },

    getRefreshButton: function() {
      return $(".js-ai-stats-refresh-button");
    },

    getStatusDisplay: function() {
      return $(".js-ai-stats-status");
    },

    getLastUpdatedTime: function() {
      return $(".js-stat-last-updated-time");
    },

    attachEventListeners: function() {
      const $document = $(document);

      $document.on("click", ".js-ai-stats-refresh-button", (event) => {
        const button = event.currentTarget;
        const url = button.dataset.url;
        const statusUrl = button.dataset.statusUrl;

        this.getRefreshButton().addClass("u-hidden");
        this.getStatusDisplay().removeClass("u-hidden");

        App.Ajax
          .request({
            url: url,
            method: "POST",
            dataType: "json"
          })
          .then((data) => {
            const finalStatusUrl = data.status_url || statusUrl;
            this.startPolling(finalStatusUrl);
          })
          .catch(() => {
            this.getRefreshButton().removeClass("u-hidden");
            this.getStatusDisplay().addClass("u-hidden");
            alert("Error refreshing AI stats. Please try again.");
          });
      });
    },

    checkInitialStatus: function() {
      const $statusDisplay = this.getStatusDisplay();

      if ($statusDisplay.length && !$statusDisplay.hasClass("u-hidden")) {
        const statusUrl = $statusDisplay.data("status-url");
        if (statusUrl) {
          this.startPolling(statusUrl);
        }
      }
    },

    startPolling: function(statusUrl) {
      const maxAttempts = 300;
      let attempts = 0;

      const poll = () => {
        if (attempts >= maxAttempts) {
          alert("Timeout beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
          return;
        }

        attempts++;

        App.Ajax
          .request({
            url: statusUrl,
            method: "GET",
            dataType: "json"
          })
          .then((response) => {
            if (response.status === "completed") {
              this.finishPolling(response);
            } else if (response.status === "failed") {
              this.resetButton();
              alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
            } else {
              setTimeout(poll, this.poolingTimeout);
            }
          })
          .catch(() => {
            setTimeout(poll, this.poolingTimeout);
          });
      };

      poll();
    },

    finishPolling: function(response) {
      this.getRefreshButton().removeClass("u-hidden");
      this.getStatusDisplay().addClass("u-hidden");

      if (response.last_updated_at) {
        this.updateTimestamp(response.last_updated_at);
      }
    },

    updateTimestamp: function(timestamp) {
      this.getLastUpdatedTime().text(timestamp);
    },

    resetButton: function() {
      this.getRefreshButton().removeClass("u-hidden");
      this.getStatusDisplay().addClass("u-hidden");
    }
  };
}).call(this);

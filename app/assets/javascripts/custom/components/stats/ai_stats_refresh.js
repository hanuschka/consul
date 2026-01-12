(function() {
  "use strict";

  App.AiStatsRefresh = {
    poolingTimeout: 7000,
    pollingActive: false,

    initialize: function() {
      this.attachEventListeners();
      this.attachTurbolinksListeners();
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

    getParticipationStats: function() {
      return $(".js-poll-participation-stats");
    },

    attachEventListeners: function() {
      const $document = $(document);

      $document.on("click", ".js-ai-stats-refresh-button", (event) => {
        const button = event.currentTarget;
        const url = button.dataset.url;
        const statusUrl = button.dataset.statusUrl;
        const section = button.dataset.section;

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
            this.startPolling(finalStatusUrl, section);
          })
          .catch(() => {
            this.getRefreshButton().removeClass("u-hidden");
            this.getStatusDisplay().addClass("u-hidden");
            alert("Error refreshing AI stats. Please try again.");
          });
      });
    },

    attachTurbolinksListeners: function() {
      const $document = $(document);

      $document.on("turbolinks:before-visit", () => {
        this.stopPolling();
      });
    },

    checkInitialStatus: function() {
      const $statusDisplay = this.getStatusDisplay();

      if ($statusDisplay.length && !$statusDisplay.hasClass("u-hidden")) {
        const statusUrl = $statusDisplay.data("status-url");
        const section = $statusDisplay.data("section");
        if (statusUrl) {
          this.startPolling(statusUrl, section);
        }
      }
    },

    startPolling: function(statusUrl, section) {
      this.pollingActive = true;
      const maxAttempts = 300;
      let attempts = 0;

      const urlWithSection = section ? `${statusUrl}?section=${section}` : statusUrl;

      const poll = () => {
        if (!this.pollingActive) {
          return;
        }

        if (attempts >= maxAttempts) {
          this.pollingActive = false;
          alert("Timeout beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
          return;
        }

        attempts++;

        App.Ajax
          .request({
            url: urlWithSection,
            method: "GET",
            dataType: "json"
          })
          .then((response) => {
            if (!this.pollingActive) {
              return;
            }

            if (response.status === "completed") {
              this.pollingActive = false;
              this.finishPolling(response);
            } else if (response.status === "failed") {
              this.pollingActive = false;
              this.resetButton();
              alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
            } else {
              setTimeout(poll, this.poolingTimeout);
            }
          })
          .catch(() => {
            if (this.pollingActive) {
              setTimeout(poll, this.poolingTimeout);
            }
          });
      };

      poll();
    },

    stopPolling: function() {
      this.pollingActive = false;
    },

    finishPolling: function(response) {
      this.getRefreshButton().removeClass("u-hidden");
      this.getStatusDisplay().addClass("u-hidden");

      if (response.last_updated_at) {
        this.updateTimestamp(response.last_updated_at);
      }

      if (response.sections_html) {
        this.updateSections(response.sections_html);
      }
    },

    updateTimestamp: function(timestamp) {
      this.getLastUpdatedTime().text(timestamp);
    },

    updateSections: function(html) {
      this.getParticipationStats().html(html);
    },

    resetButton: function() {
      this.getRefreshButton().removeClass("u-hidden");
      this.getStatusDisplay().addClass("u-hidden");
    }
  };
}).call(this);

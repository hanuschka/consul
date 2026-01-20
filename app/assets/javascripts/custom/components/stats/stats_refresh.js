(function() {
  "use strict";

  App.StatsRefresh = {
    statusCheckTimeout: 7000,
    statusCheckActive: false,

    initialize: function() {
      this.attachEventListeners();
      this.attachTurbolinksListeners();
      this.checkInitialStatus();
    },

    getLastUpdatedTime: function() {
      return $(".js-stat-last-updated-time");
    },

    getParticipationStats: function(section) {
      if (section === "key_metrics") {
        return $(".js-participation-stats-key-metrics");
      } else if (section === "analysis") {
        return $(".js-participation-stats-analysis");
      }
      return $(".js-participation-stats");
    },

    attachEventListeners: function() {
      const $document = $(document);

      $document.on("click", ".js-stats-refresh-button", (event) => {
        const $button = $(event.currentTarget);
        const $container = $button.closest(".js-stats-button-container");
        const url = $button.data("url");
        const statusCheckUrl = $button.data("status-check-url");
        const section = $button.data("section");

        $button.addClass("u-hidden");
        $container.find(".js-stats-status").removeClass("u-hidden");

        App.Ajax
          .request({
            url: url,
            method: "POST",
            dataType: "json",
            data: section ? { section: section } : {}
          })
          .then((response) => {
            if (statusCheckUrl) {
              const finalStatusCheckUrl = response.status_url || statusCheckUrl;
              this.startStatusCheck(finalStatusCheckUrl, section, $container);
            } else {
              $button.removeClass("u-hidden");
              $container.find(".js-stats-status").addClass("u-hidden");

              if (response.last_updated_at) {
                this.updateTimestamp(response.last_updated_at);
              }

              if (response.sections_html) {
                this.updateSections(response.sections_html, section);
              }
            }
          })
          .catch(() => {
            $button.removeClass("u-hidden");
            $container.find(".js-stats-status").addClass("u-hidden");
            alert("Fehler beim Aktualisieren der Statistiken. Bitte versuchen Sie es erneut.");
          });
      });
    },

    attachTurbolinksListeners: function() {
      const $document = $(document);

      $document.on("turbolinks:before-visit", () => {
        this.stopStatusCheck();
      });
    },

    checkInitialStatus: function() {
      $(".js-stats-status").each((index, element) => {
        const $statusDisplay = $(element);
        if (!$statusDisplay.hasClass("u-hidden")) {
          const statusCheckUrl = $statusDisplay.data("status-check-url");
          const section = $statusDisplay.data("section");
          const $container = $statusDisplay.closest(".js-stats-button-container");
          if (statusCheckUrl) {
            this.startStatusCheck(statusCheckUrl, section, $container);
          }
        }
      });
    },

    startStatusCheck: function(statusUrl, section, $container) {
      this.statusCheckActive = true;
      const maxAttempts = 300;
      let attempts = 0;

      const urlWithSection = section ? `${statusUrl}?section=${section}` : statusUrl;

      const poll = () => {
        if (!this.statusCheckActive) {
          return;
        }

        if (attempts >= maxAttempts) {
          this.statusCheckActive = false;
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
            if (!this.statusCheckActive) {
              return;
            }

            if (response.status === "completed") {
              this.statusCheckActive = false;
              this.finishStatusCheck(response, $container, section);
            } else if (response.status === "failed") {
              this.statusCheckActive = false;
              this.resetButton($container);
              alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
            } else {
              setTimeout(poll, this.statusCheckTimeout);
            }
          })
          .catch(() => {
            if (this.statusCheckActive) {
              setTimeout(poll, this.statusCheckTimeout);
            }
          });
      };

      poll();
    },

    stopStatusCheck: function() {
      this.statusCheckActive = false;
    },

    finishStatusCheck: function(response, $container, section) {
      $container.find(".js-stats-refresh-button").removeClass("u-hidden");
      $container.find(".js-stats-status").addClass("u-hidden");

      this.updateTimestamp(response.last_updated_at);
      this.updateSections(response.sections_html, section);
    },

    updateTimestamp: function(timestamp) {
      const $timeElement = this.getLastUpdatedTime();
      $timeElement.text(timestamp);
      $timeElement.closest(".stats-last-updated-item").removeClass("u-hidden");
    },

    updateSections: function(html, section) {
      this.getParticipationStats(section).html(html);
    },

    resetButton: function($container) {
      $container.find(".js-stats-refresh-button").removeClass("u-hidden");
      $container.find(".js-stats-status").addClass("u-hidden");
    }
  };
}).call(this);

(function() {
  "use strict";

  App.AiStatsRefresh = {
    initialize: function() {
      this.attachEventListeners();
      this.checkInitialStatus();
    },

    attachEventListeners: function() {
      const $document = $(document);

      $document.on("click", ".js-ai-stats-refresh-button", (event) => {
        const button = event.currentTarget;
        const url = button.dataset.url;
        const statusUrl = button.dataset.statusUrl;

        button.disabled = true;
        $(".js-ai-stats-status").removeClass("u-hidden");

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
            button.disabled = false;
            $(".js-ai-stats-status").addClass("u-hidden");
            alert("Error refreshing AI stats. Please try again.");
          });
      });
    },

    checkInitialStatus: function() {
      const $status = $(".js-ai-stats-status");
      if ($status.length && !$status.hasClass("u-hidden")) {
        const statusUrl = $status.data("status-url");
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
              setTimeout(poll, 2000);
            }
          })
          .catch(() => {
            setTimeout(poll, 5000);
          });
      };

      poll();
    },

    finishPolling: function(response) {
      const $button = $(".js-ai-stats-refresh-button");
      const $status = $(".js-ai-stats-status");

      $button.prop("disabled", false);
      $status.addClass("u-hidden");

      if (response.last_updated_at) {
        this.updateTimestamp(response.last_updated_at);
      }
    },

    updateTimestamp: function(timestamp) {
      const $timestampContainer = $(".stats-last-updated-container");
      if ($timestampContainer.length) {
        $timestampContainer.find(".stats-last-updated-item").text(
          "AI analysis last updated: " + timestamp
        );
      }
    },

    resetButton: function() {
      const $button = $(".js-ai-stats-refresh-button");
      const $status = $(".js-ai-stats-status");

      $button.prop("disabled", false);
      $status.addClass("u-hidden");
    }
  };
}).call(this);

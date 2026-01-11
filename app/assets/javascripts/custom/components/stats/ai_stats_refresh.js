(function() {
  "use strict";

  App.AiStatsRefresh = {
    initialize: function() {
      this.attachEventListeners();
    },

    attachEventListeners: function() {
      const $document = $(document);

      $document.on("ajax:beforeSend", ".js-ai-stats-refresh-form", (event) => {
        this.showLoadingModal();
      });

      $document.on("ajax:success", ".js-ai-stats-refresh-form", (event, data) => {
        const form = event.currentTarget;
        const statusUrl = data.status_url || form.action.replace("refresh_ai_stats", "ai_stats_status");
        this.startPolling(statusUrl);
      });

      $document.on("ajax:error", ".js-ai-stats-refresh-form", (event) => {
        this.hideLoadingModal();
        alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
      });
    },

    startPolling: function(statusUrl) {
      const maxAttempts = 300;
      let attempts = 0;

      const poll = () => {
        if (attempts >= maxAttempts) {
          this.hideLoadingModal();
          alert("Timeout beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
          return;
        }

        attempts++;

        $.ajax({
          url: statusUrl,
          method: "GET",
          dataType: "json"
        }).then((response) => {
          if (response.status === "completed") {
            this.hideLoadingModal();
            window.location.reload();
          } else if (response.status === "failed") {
            this.hideLoadingModal();
            alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
          } else {
            setTimeout(poll, 2000);
          }
        }).catch(() => {
          this.hideLoadingModal();
          alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
        });
      };

      poll();
    },

    showLoadingModal: function() {
      App.SharedModal.open("ai-stats-loading-modal");
    },

    hideLoadingModal: function() {
      App.SharedModal.closeById("ai-stats-loading-modal");
    }
  };
}).call(this);


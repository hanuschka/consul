(function() {
  "use strict";

  App.AiStatsRefresh = {
    initialize: function() {
      this.attachEventListeners();
    },

    attachEventListeners: function() {
      $(document).on("ajax:beforeSend", "form[action*='refresh_ai_stats']", (event) => {
        this.showLoadingModal();
      });

      $(document).on("ajax:success", "form[action*='refresh_ai_stats']", (event, data) => {
        const form = event.currentTarget;
        const statusUrl = data.status_url || form.action.replace("refresh_ai_stats", "ai_stats_status");
        this.startPolling(statusUrl);
      });

      $(document).on("ajax:error", "form[action*='refresh_ai_stats']", (event) => {
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
      const modal = document.getElementById("ai-stats-loading-modal");
      if (modal) {
        modal.style.display = "flex";
        document.body.style.overflow = "hidden";
      }
    },

    hideLoadingModal: function() {
      const modal = document.getElementById("ai-stats-loading-modal");
      if (modal) {
        modal.style.display = "none";
        document.body.style.overflow = "";
      }
    }
  };
}).call(this);


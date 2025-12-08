(function() {
  "use strict";

  App.AiStatsRefresh = {
    initialize: function() {
      this.attachEventListeners();
    },

    attachEventListeners: function() {
      const self = this;
      $(document).on("ajax:beforeSend", "form", function(event) {
        if (self.isAiStatsRefreshForm(this)) {
          self.showLoadingModal();
        }
      });

      $(document).on("ajax:success", "form", function(event) {
        if (self.isAiStatsRefreshForm(this)) {
          self.hideLoadingModal();
          window.location.reload();
        }
      });

      $(document).on("ajax:error", "form", function(event) {
        if (self.isAiStatsRefreshForm(this)) {
          self.hideLoadingModal();
          alert("Fehler beim Aktualisieren der AI-Statistiken. Bitte versuchen Sie es erneut.");
        }
      });
    },

    isAiStatsRefreshForm: function(element) {
      return element && element.tagName === "FORM" && element.action.includes("refresh_ai_stats");
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


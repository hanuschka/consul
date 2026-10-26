(function() {
  "use strict";

  App.SessionTimeoutWarning = {
    syncTimer: null,

    initialize: function() {
      var container = document.querySelector(".js-session-timeout-warning");
      if (!container) return;

      this.timeoutMinutes = parseInt(container.dataset.timeoutMinutes, 10);
      this.warningMinutes = parseInt(container.dataset.warningMinutes, 10);
      this.keepaliveUrl = container.dataset.keepaliveUrl;
      this.statusUrl = container.dataset.statusUrl;
      this.dialog = container.querySelector(".js-session-timeout-dialog");
      this.extendButton = container.querySelector(".js-session-timeout-extend");
      this.logoutButton = container.querySelector(".js-session-timeout-logout");
      this.countdownDisplay = container.querySelector(".js-session-timeout-countdown");

      this.bindEvents();
      this.resetTimers();
    },

    bindEvents: function() {
      this.extendButton.addEventListener("click", this.handleExtend.bind(this));
      this.logoutButton.addEventListener("click", this.handleLogout.bind(this));

      this.dialog.addEventListener("cancel", this.handleExtend.bind(this));
    },

    resetTimers: function() {
      this.scheduleSync(this.timeoutMinutes * 60);
    },

    scheduleSync: function(remainingSeconds) {
      this.clearTimers();

      var delay = Math.max(remainingSeconds - this.warningMinutes * 60, 0) * 1000;
      this.syncTimer = setTimeout(this.syncWithServer.bind(this), delay);
    },

    syncWithServer: function() {
      this.clearTimers();

      App.Ajax
        .request({ method: "GET", url: this.statusUrl, dataType: "json" })
        .done(this.handleStatus.bind(this))
        .fail(this.handleStatusFailure.bind(this));
    },

    handleStatus: function(response) {
      var remainingSeconds = response.remaining_seconds;

      if (remainingSeconds <= 0) {
        this.handleLogout();
      } else if (remainingSeconds <= this.warningMinutes * 60) {
        this.showWarning(remainingSeconds);
      } else {
        this.hideWarning();
        this.scheduleSync(remainingSeconds);
      }
    },

    handleStatusFailure: function(xhr) {
      if (xhr.status === 401) {
        this.reloadPage();
      } else if (this.dialog.open) {
        this.handleLogout();
      } else {
        this.showWarning(this.warningMinutes * 60);
      }
    },

    handleExtendFailure: function(xhr) {
      if (xhr.status === 401) {
        this.reloadPage();
      } else {
        this.showWarning(this.remainingSeconds);
      }
    },

    reloadPage: function() {
      window.location.assign(window.location.pathname + window.location.search);
    },

    clearTimers: function() {
      if (this.syncTimer) {
        clearTimeout(this.syncTimer);
        this.syncTimer = null;
      }

      if (this.countdownInterval) {
        clearInterval(this.countdownInterval);
        this.countdownInterval = null;
      }
    },

    showWarning: function(remainingSeconds) {
      this.remainingSeconds = remainingSeconds;
      this.updateCountdown();
      this.countdownInterval = setInterval(this.tickCountdown.bind(this), 1000);

      if (!this.dialog.open) {
        this.dialog.showModal();
        this.extendButton.focus();
      }
    },

    hideWarning: function() {
      if (this.dialog.open) {
        this.dialog.close();
      }

      if (this.countdownInterval) {
        clearInterval(this.countdownInterval);
        this.countdownInterval = null;
      }
    },

    tickCountdown: function() {
      this.remainingSeconds -= 1;

      if (this.remainingSeconds <= 0) {
        this.syncWithServer();
        return;
      }

      this.updateCountdown();
    },

    updateCountdown: function() {
      var minutes = Math.floor(this.remainingSeconds / 60);
      var seconds = this.remainingSeconds % 60;
      var padded = minutes + ":" + (seconds < 10 ? "0" : "") + seconds;
      this.countdownDisplay.textContent = padded;
    },

    handleExtend: function(event) {
      if (event) {
        event.preventDefault();
      }

      this.hideWarning();

      App.Ajax
        .post(this.keepaliveUrl)
        .done(this.resetTimers.bind(this))
        .fail(this.handleExtendFailure.bind(this));
    },

    handleLogout: function() {
      this.clearTimers();
      this.hideWarning();
      this.submitSignOut();
    },

    submitSignOut: function() {
      $.rails.handleMethod($("<a>", { href: "/users/sign_out", "data-method": "delete" }));
    }
  };
}).call(this);

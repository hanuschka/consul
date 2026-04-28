(function() {
  "use strict";

  App.SessionTimeoutWarning = {
    warningTimer: null,
    logoutTimer: null,

    initialize: function() {
      var container = document.querySelector(".js-session-timeout-warning");
      if (!container) return;

      this.timeoutMinutes = parseInt(container.dataset.timeoutMinutes, 10);
      this.warningMinutes = parseInt(container.dataset.warningMinutes, 10);
      this.keepaliveUrl = container.dataset.keepaliveUrl;
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

      this.dialog.addEventListener("keydown", this.handleKeydown.bind(this));
      this.dialog.addEventListener("cancel", this.handleExtend.bind(this));
    },

    resetTimers: function() {
      this.clearTimers();

      var warningDelay = (this.timeoutMinutes - this.warningMinutes) * 60 * 1000;
      var logoutDelay = this.timeoutMinutes * 60 * 1000;

      this.warningTimer = setTimeout(this.showWarning.bind(this), warningDelay);
      this.logoutTimer = setTimeout(this.handleLogout.bind(this), logoutDelay);
    },

    clearTimers: function() {
      if (this.warningTimer) {
        clearTimeout(this.warningTimer);
        this.warningTimer = null;
      }

      if (this.logoutTimer) {
        clearTimeout(this.logoutTimer);
        this.logoutTimer = null;
      }

      if (this.countdownInterval) {
        clearInterval(this.countdownInterval);
        this.countdownInterval = null;
      }
    },

    showWarning: function() {
      this.remainingSeconds = this.warningMinutes * 60;
      this.updateCountdown();
      this.countdownInterval = setInterval(this.tickCountdown.bind(this), 1000);

      this.dialog.showModal();
      App.FocusTrap.setBackgroundInert([this.dialog]);
      this.extendButton.focus();
    },

    hideWarning: function() {
      if (this.dialog.open) {
        this.dialog.close();
      }

      App.FocusTrap.removeBackgroundInert();

      if (this.countdownInterval) {
        clearInterval(this.countdownInterval);
        this.countdownInterval = null;
      }
    },

    tickCountdown: function() {
      this.remainingSeconds -= 1;

      if (this.remainingSeconds <= 0) {
        this.handleLogout();
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
        .then(this.resetTimers.bind(this));
    },

    handleLogout: function() {
      this.clearTimers();
      this.hideWarning();
      this.submitSignOut();
    },

    submitSignOut: function() {
      $.rails.handleMethod($("<a>", { href: "/users/sign_out", "data-method": "delete" }));
    },

    handleKeydown: function(event) {
      if (event.key === "Tab") {
        App.FocusTrap.handleTabKey(event, this.dialog);
      }
    }
  };
}).call(this);

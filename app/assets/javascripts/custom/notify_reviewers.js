(function() {
  "use strict";

  App.NotifyReviewers = {
    SUCCESS_DURATION: 2200,

    initialize() {
      $(document).on("click", ".js-notify-reviewers", this.handleClick.bind(this));
    },

    handleClick(event) {
      event.preventDefault();

      const button = event.currentTarget;
      if (button.classList.contains("-loading") || button.classList.contains("-success")) return;

      const url = button.getAttribute("href");

      this.setLoadingState(button);

      App.Ajax
        .request({
          url,
          type: "POST",
          dataType: "json"
        })
        .then(() => this.setSuccessState(button))
        .catch(() => this.setErrorState(button));
    },

    setLoadingState(button) {
      const icon = button.querySelector(".js-notify-reviewers-icon");

      this.lockButtonWidth(button);

      button.dataset.originalIconClass = icon.className;
      icon.className = "fas fa-circle-notch fa-spin js-notify-reviewers-icon";
      button.classList.remove("-success", "-error");
      button.classList.add("-loading");
      button.setAttribute("aria-busy", "true");
    },

    lockButtonWidth(button) {
      if (button.dataset.originalWidth) return;
      const width = button.getBoundingClientRect().width;
      button.dataset.originalWidth = button.style.width || "";
      button.style.width = `${Math.ceil(width)}px`;
    },

    unlockButtonWidth(button) {
      if (button.dataset.originalWidth === undefined) return;
      button.style.width = button.dataset.originalWidth;
      delete button.dataset.originalWidth;
    },

    setSuccessState(button) {
      const icon = button.querySelector(".js-notify-reviewers-icon");
      const label = button.querySelector(".js-notify-reviewers-label");

      icon.className = "fas fa-check js-notify-reviewers-icon";
      button.classList.remove("-loading");
      button.classList.add("-success");
      button.removeAttribute("aria-busy");

      if (label) {
        button.dataset.originalLabel = label.textContent;
        label.textContent = "Benachrichtigt";
      }

      setTimeout(() => this.resetState(button), this.SUCCESS_DURATION);
    },

    setErrorState(button) {
      const icon = button.querySelector(".js-notify-reviewers-icon");

      icon.className = "fas fa-exclamation-triangle js-notify-reviewers-icon";
      button.classList.remove("-loading");
      button.classList.add("-error");
      button.removeAttribute("aria-busy");

      setTimeout(() => this.resetState(button), this.SUCCESS_DURATION);
    },

    resetState(button) {
      const icon = button.querySelector(".js-notify-reviewers-icon");
      const label = button.querySelector(".js-notify-reviewers-label");
      const originalIconClass = button.dataset.originalIconClass;
      const originalLabel = button.dataset.originalLabel;

      if (originalIconClass) {
        icon.className = originalIconClass;
        delete button.dataset.originalIconClass;
      }

      if (originalLabel && label) {
        label.textContent = originalLabel;
        delete button.dataset.originalLabel;
      }

      button.classList.remove("-loading", "-success", "-error");
      this.unlockButtonWidth(button);
    }
  };
}).call(this);

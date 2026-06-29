App.Studio.ContentBlocks.CopyFeedback = {
  FEEDBACK_DURATION: 1200,
  TOOLTIP_TEXT: "Kopiert!",
  TOOLTIP_GAP: 10,
  SUPPORTS_POPOVER: HTMLElement.prototype.hasOwnProperty("showPopover"),

  show(button) {
    this.showCheckIcon(button);
    this.showTooltip(button);
    this.scheduleReset(button);
  },

  showCheckIcon(button) {
    const icon = button.querySelector("i");

    if (button.dataset.copyOriginalIcon === undefined) {
      button.dataset.copyOriginalIcon = icon.className;
    }

    icon.className = "fa fas fa-check";
    button.classList.add("-copied");
  },

  showTooltip(button) {
    this.removeTooltip(button);

    const tooltip = document.createElement("div");
    tooltip.className = "studio-copy-feedback-tooltip";
    tooltip.textContent = this.TOOLTIP_TEXT;

    if (this.SUPPORTS_POPOVER) {
      tooltip.setAttribute("popover", "manual");
    }

    document.body.appendChild(tooltip);
    this.positionTooltip(tooltip, button);

    if (this.SUPPORTS_POPOVER) {
      tooltip.showPopover();
    }

    button.copyFeedbackTooltip = tooltip;

    requestAnimationFrame(() => tooltip.classList.add("-visible"));
  },

  positionTooltip(tooltip, button) {
    const rect = button.getBoundingClientRect();

    tooltip.style.top = `${rect.top + rect.height / 2}px`;
    tooltip.style.left = `${rect.left - this.TOOLTIP_GAP}px`;
  },

  scheduleReset(button) {
    clearTimeout(button.copyFeedbackTimeout);
    button.copyFeedbackTimeout = setTimeout(this.reset.bind(this, button), this.FEEDBACK_DURATION);
  },

  reset(button) {
    const icon = button.querySelector("i");

    if (button.dataset.copyOriginalIcon !== undefined) {
      icon.className = button.dataset.copyOriginalIcon;
      delete button.dataset.copyOriginalIcon;
    }

    button.classList.remove("-copied");
    this.removeTooltip(button);
  },

  removeTooltip(button) {
    const tooltip = button.copyFeedbackTooltip;

    if (!tooltip) return

    tooltip.classList.remove("-visible");

    setTimeout(() => {
      if (this.SUPPORTS_POPOVER && tooltip.matches(":popover-open")) {
        tooltip.hidePopover();
      }

      tooltip.remove();
    }, 200);

    button.copyFeedbackTooltip = null;
  }
};

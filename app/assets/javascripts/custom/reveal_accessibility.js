(function() {
  "use strict";

  App.RevealAccessibility = {
    initialize: function() {
      if (this.bound) return;

      this.bound = true;

      const $document = $(document);

      $document.on("open.zf.reveal", ".reveal", this.handleOpen.bind(this));
      $document.on("closed.zf.reveal", ".reveal", this.handleClose.bind(this));
      $document.on("keydown", ".reveal", this.handleKeydown.bind(this));
    },

    handleOpen: function(event) {
      const modal = event.currentTarget;

      if (!modal.getAttribute("role")) {
        modal.setAttribute("role", "dialog");
      }

      modal.setAttribute("aria-modal", "true");

      App.FocusTrap.setBackgroundInert([modal], modal);

      setTimeout(() => {
        const focusable = App.FocusTrap.getFocusableElements(modal);

        if (focusable.length > 0) {
          focusable[0].focus();
        } else {
          modal.setAttribute("tabindex", "-1");
          modal.focus();
        }
      }, 50);
    },

    handleClose: function() {
      App.FocusTrap.removeBackgroundInert();
    },

    handleKeydown: function(event) {
      if (event.key !== "Tab" && event.which !== 9) return;

      App.FocusTrap.handleTabKey(event, event.currentTarget);
    }
  };
}).call(this);

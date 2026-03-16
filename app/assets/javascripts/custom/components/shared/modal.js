(function() {
  "use strict";

  App.SharedModal = {
    openCount: 0,

    initialize: function() {
      this.attachEventListeners();
    },

    attachEventListeners: function() {
      const $document = $(document);

      $document.on("click", ".js-shared-modal-close", (event) => {
        this.close(event.currentTarget);
      });

      $document.on("click", "dialog.shared-modal", (event) => {
        const dialog = event.currentTarget;
        if (event.target !== dialog) return
        if (dialog.hasAttribute("data-no-backdrop-close")) return

        dialog.close();
        this.unlockScroll();
      });
    },

    open: function(modalId) {
      const modal = document.getElementById(modalId);
      modal.showModal();
      this.lockScroll();
    },

    close: function(closeButton) {
      const modal = closeButton.closest("dialog");
      modal.close();
      this.unlockScroll();
    },

    closeById: function(modalId) {
      const modal = document.getElementById(modalId);
      modal.close();
      this.unlockScroll();
    },

    lockScroll: function() {
      this.openCount++;
      if (this.openCount > 1) return

      const htmlEl = document.documentElement;
      const hasScroll = document.body.scrollHeight > window.innerHeight;
      this.savedScrollTop = window.pageYOffset;

      if (hasScroll) {
        htmlEl.classList.add("shared-modal-has-scroll");
        htmlEl.style.top = -this.savedScrollTop + "px";
      }

      htmlEl.classList.add("is-shared-modal-open");
    },

    unlockScroll: function() {
      this.openCount = Math.max(0, this.openCount - 1);
      if (this.openCount > 0) return

      const htmlEl = document.documentElement;
      const scrollTop = parseInt(htmlEl.style.top, 10) || 0;
      htmlEl.classList.remove("is-shared-modal-open", "shared-modal-has-scroll");
      htmlEl.style.top = "";

      if (scrollTop) {
        window.scrollTo(0, -scrollTop);
      }
    }
  };
}).call(this);

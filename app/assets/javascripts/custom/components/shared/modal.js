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
        document.body.style.overflow = "";
      });
    },

    open: function(modalId) {
      const modal = document.getElementById(modalId);
      this.bindEscHandling(modal);
      this.bindInertCleanup(modal);
      modal.showModal();
      App.FocusTrap.setBackgroundInert([modal]);
      this.lockScroll();
    },

    bindInertCleanup: function(modal) {
      if (modal.dataset.inertCleanupBound) return;

      modal.addEventListener("close", () => {
        App.FocusTrap.removeBackgroundInert();
      });

      modal.dataset.inertCleanupBound = "true";
    },

    // Native Esc closes the dialog without going through close()/closeById(),
    // so the scroll lock has to be released here. Dialogs marked with
    // data-no-esc-close keep their Foundation-era "Esc does nothing" behavior.
    bindEscHandling: function(modal) {
      if (modal.dataset.escHandlingBound) return

      modal.addEventListener("keydown", (event) => {
        if (event.key !== "Escape") return

        if (modal.hasAttribute("data-no-esc-close")) {
          event.preventDefault();
          return
        }

        this.unlockScroll();
      });

      modal.dataset.escHandlingBound = "true";
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
        // behavior: "instant" overrides any CSS `scroll-behavior: smooth`,
        // which would otherwise animate the restore — making the page snap to
        // the top and then visibly scroll back down after the modal closes.
        window.scrollTo({ top: -scrollTop, left: 0, behavior: "instant" });
      }
    }
  };
}).call(this);

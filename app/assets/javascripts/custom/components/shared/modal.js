(function() {
  "use strict";

  App.SharedModal = {
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
        document.body.style.overflow = "";
      });
    },

    open: function(modalId) {
      const modal = document.getElementById(modalId);
      modal.showModal();
      document.body.style.overflow = "hidden";
    },

    close: function(closeButton) {
      const modal = closeButton.closest("dialog");
      modal.close();
      document.body.style.overflow = "";
    },

    closeById: function(modalId) {
      const modal = document.getElementById(modalId);
      modal.close();
      document.body.style.overflow = "";
    }
  };
}).call(this);

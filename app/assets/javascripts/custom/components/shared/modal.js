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

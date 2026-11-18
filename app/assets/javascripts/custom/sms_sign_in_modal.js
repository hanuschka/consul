(function() {
  "use strict";

  App.SmsSignInModal = {
    modalId: "sms-sign-in-modal",

    initialize: function() {
      if (this.bound) return;

      this.bound = true;

      const $document = $(document);

      $document.on("click", "a.js-sms-sign-in", this.handleClick.bind(this));
      $document.on("turbolinks:before-cache", this.destroy.bind(this));
    },

    handleClick: function(event) {
      if (event.which > 1 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;

      event.preventDefault();

      const href = event.currentTarget.href;

      $.ajax({ url: href, dataType: "script" }).fail(function() {
        window.location.href = href;
      });
    },

    show: function(containerHtml, contentHtml, focusId) {
      let $modal = $("#" + this.modalId);

      if ($modal.length > 0 && !$modal.data("zfPlugin")) {
        $modal.closest(".reveal-overlay").remove();
        $modal.remove();
        $modal = $();
      }

      if ($modal.length === 0) {
        $modal = $(containerHtml).appendTo("body");
        $modal.foundation();
      }

      $modal.find(".js-sms-sign-in-modal-content").html(contentHtml);

      if (!$modal.data("zfPlugin").isActive) {
        $modal.foundation("open");
      }

      const field = document.getElementById(focusId);

      if (field) {
        field.focus();
      }
    },

    destroy: function() {
      const $modal = $("#" + this.modalId);

      if ($modal.length === 0) return;

      if ($modal.data("zfPlugin")) {
        $modal.foundation("destroy");
      }

      $modal.remove();
    }
  };
}).call(this);

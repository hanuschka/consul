(function() {
  "use strict";

  App.FlashMessages = {
    ANNOUNCE_DELAY: 100,
    AUTO_DISMISS_MS: 5000,
    EXIT_MS: 200,

    initialize: function() {
      var $toasts = $(".js-flash-message");
      if (!$toasts.length) return;

      this.announce($toasts);
      this.bindToasts($toasts);
    },

    // Mirror toast text into a visually-hidden live region so screen readers
    // announce it without the toast stealing focus.
    announce: function($toasts) {
      setTimeout(function() {
        var $polite = $(".js-flash-live-region");
        var $assertive = $(".js-flash-alert-region");

        $toasts.each(function() {
          var $toast = $(this);
          var text = $.trim($toast.find(".toast__text").text());
          var $region = $toast.data("live") === "assertive" ? $assertive : $polite;
          $region.append($("<div></div>").text(text));
        });
      }, App.FlashMessages.ANNOUNCE_DELAY);
    },

    bindToasts: function($toasts) {
      var self = this;

      $toasts.each(function() {
        var $toast = $(this);

        $toast.on("click", ".js-toast-close", function() {
          self.dismiss($toast);
        });

        $toast.on("keydown", function(event) {
          if (event.key === "Escape" || event.keyCode === 27) {
            self.dismiss($toast);
          }
        });

        if ($toast.data("autodismiss") === true) {
          self.scheduleDismiss($toast);
          $toast.on("mouseenter focusin", function() {
            self.cancelDismiss($toast);
          });
          $toast.on("mouseleave focusout", function() {
            self.scheduleDismiss($toast);
          });
        }
      });
    },

    scheduleDismiss: function($toast) {
      var self = this;
      this.cancelDismiss($toast);
      var timer = setTimeout(function() {
        self.dismiss($toast);
      }, this.AUTO_DISMISS_MS);
      $toast.data("dismissTimer", timer);
    },

    cancelDismiss: function($toast) {
      var timer = $toast.data("dismissTimer");
      if (timer) {
        clearTimeout(timer);
        $toast.removeData("dismissTimer");
      }
    },

    dismiss: function($toast) {
      this.cancelDismiss($toast);
      if ($toast.hasClass("toast--leaving")) return;

      $toast.addClass("toast--leaving");
      setTimeout(function() {
        $toast.remove();
      }, this.EXIT_MS);
    }
  };
}).call(this);

(function() {
  "use strict";
  App.ClickOutWarning = {
    initialize: function() {
      $("body").on("click", "a", function(event) {
        if (document.querySelector("meta[name='external-links']").getAttribute("content") === 'true' ) {
          var showWarning = true;
        }

        if (event.currentTarget.matches(".glightbox-link, .glightbox")) {
          return
        }

        if (showWarning && event.currentTarget.hostname.length && location.hostname !== event.currentTarget.hostname) {
          var answer = window.confirm("Mit Bestätigung stimmen Sie zu, die Webseite zu verlassen.");

          if (!answer) {
            event.preventDefault()
          }
        }
      });
    }
  }
}).call(this);

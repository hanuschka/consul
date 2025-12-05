(function() {
  "use strict";
  App.ClickOutWarning = {
    initialize: function() {
      $("body").on("click", "a", function(event) {
        if (document.querySelector("meta[name='external-links']").getAttribute("content") === 'true' ) {
          var showWarning = true;
        }

        if ( showWarning && this.hostname.length && location.hostname !== this.hostname ) {

          var answer = window.confirm("Mit Bestätigung stimmen Sie zu, die Webseite zu verlassen.");
          if ( !answer ) {
            event.preventDefault()
          }

        }
      });
    }
  }
}).call(this);

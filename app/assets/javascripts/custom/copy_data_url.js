(function() {
  "use strict";
  App.CopyDataUrl = {
    initialize: function() {
      $(".js-copy-data-url").on("click", function(event) {
        event.preventDefault();
        var url = $(this).data("url");
        navigator.clipboard.writeText(url);
      });
    }
  };
}).call(this);

(function() {
  "use strict";
  App.MapRefresh = {
    initialize: function() {
      $("#projekts-tabs, #edit-projekt-tabs").on("change.zf.tabs", function() {
        if ($("#tab-projekt-map:visible").length > 0 && App.Map.maps.length == 0) {
          App.Map.initialize();
        }
      });
    }
  };
}).call(this);

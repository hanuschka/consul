(function() {
  "use strict";
  App.ResourcesListComponent = {
    WIDE_MODE_CLASS: "-wide",

    initialize: function() {
      $(document).on(
        "click",
        ".js-resource-list-switch-view-button",
        this.switchResourceViewMode.bind(this)
      );
    },

    switchViewModeButton: function() {
      return $(".js-resource-list-switch-view-button");
    },

    switchResourceViewMode: function(e) {
      $(e.currentTarget)
        .closest(".resources-list")
        .toggleClass(this.WIDE_MODE_CLASS);
    }
  };
}).call(this);

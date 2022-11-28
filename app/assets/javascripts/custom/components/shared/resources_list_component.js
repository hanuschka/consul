(function() {
  "use strict";
  App.ResourcesListComponent = {
    WIDE_MODE_CLASS: "-wide",

    initialize: function() {
      $(document).on("click", ".js-resource-list-switch-view-button",
        this.switchResourceViewMode.bind(this)
      );

      $(document).on("click", ".js-resource-list-filter-dropdown-item",
        this.loadResourcesWithFilter.bind(this)
      );
    },

    switchViewModeButton: function() {
      return $(".js-resource-list-switch-view-button");
    },

    switchResourceViewMode: function(e) {
      var $switchButton = $(e.currentTarget);

      $switchButton
        .closest(".resources-list")
        .toggleClass(this.WIDE_MODE_CLASS);

      var $switchButtonIcon = $switchButton.find("i");

      $switchButtonIcon.toggleClass("fa-grip-vertical");
      $switchButtonIcon.toggleClass("fa-bars");
    },

    loadResourcesWithFilter: function(e) {
      var filterItem = e.currentTarget;

      var filterName = filterItem.dataset.name;
      var filterValue = filterItem.dataset.value;

      // console.log(filterName, filterValue)
    }
  };
}).call(this);

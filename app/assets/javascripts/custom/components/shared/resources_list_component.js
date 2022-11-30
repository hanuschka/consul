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
      var switchButton = e.currentTarget;

      switchButton
        .closest(".resources-list")
        .classList.toggle(this.WIDE_MODE_CLASS);

      var switchButtonIcon = switchButton.querySelector("i");

      switchButtonIcon.classList.toggle("fa-grip-vertical");
      switchButtonIcon.classList.toggle("fa-bars");
    },

    loadResourcesWithFilter: function(e) {
      var filterItem = e.currentTarget;

      var filterName = filterItem.dataset.name;
      var filterValue = filterItem.dataset.value;
      var resourcesList = filterItem.closest(".js-resources-list");
      var resourcesUrl = resourcesList.dataset.resourcesUrl;
      var resourcesUrlWithFilter = resourcesUrl + "?" + filterName + "=" + filterValue

      $.get(resourcesUrlWithFilter);
    }
  };
}).call(this);

(function() {
  "use strict";
  App.ResourcesListComponent = {
    WIDE_MODE_CLASS: "-wide",
    initialized: false,

    initialize: function() {
      if (this.initialized) {
        return;
      }

      $(document).on("click", ".js-resource-list-switch-view-button",
        this.switchResourceViewMode.bind(this)
      );

      $(document).on("click", ".js-resources-list .js-dropdown-item",
        this.loadResourcesWithFilter.bind(this)
      );

      this.initialized = true;
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
      e.preventDefault();

      var filterItem = e.currentTarget;

      var filterName = filterItem.dataset.name;
      var filterValue = filterItem.dataset.value;
      var resourcesList = filterItem.closest(".js-resources-list");
      var resourcesUrl = resourcesList.dataset.resourcesUrl;
      var fullPageReload = resourcesList.dataset.fullPageReload;

      if (!resourcesUrl) {
        return;
      }

      var resourcesUrlObject = new URL(resourcesUrl);
      resourcesUrlObject.searchParams.set(filterName, filterValue);
      var resultingUrl = resourcesUrlObject.toString();

      if (fullPageReload === "true") {
        Turbolinks.visit(resultingUrl);
      } else {
        $.get(resultingUrl);
      }
    }
  };
}).call(this);

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
        this.switchResourcesViewMode.bind(this)
      );

      this.initialized = true;
    },

    switchViewModeButton: function() {
      return $(".js-resource-list-switch-view-button");
    },

    switchResourcesViewMode: function(e) {
      var switchButton = e.currentTarget;
      var resourcesList = switchButton.closest(".js-resources-list");
      var currentViewModeWide = this.isResourcesListInWideMode(resourcesList);
      var cookieValue = currentViewModeWide ? "false" : "true";
      var viewCookie = resourcesList.dataset.viewCookie;

      if (viewCookie) {
        document.cookie = viewCookie + "=" + cookieValue + "; path=/; max-age=31536000; SameSite=Lax";
      } else {
        document.cookie = "wide_resources=" + cookieValue;
      }

      this.switchViewModeForAllResourcesLists();
    },

    switchViewModeForAllResourcesLists: function() {
      var resourcesListsOnPage = Array.from(document.querySelectorAll(".js-resources-list"));

      resourcesListsOnPage.forEach(function(resourcesList) {
        this.switchResourceListViewMode(resourcesList);
      }.bind(this));
    },

    isResourcesListInWideMode: function(resourcesList) {
      return resourcesList.classList.contains(this.WIDE_MODE_CLASS);
    },

    switchResourceListViewMode: function(resourcesList) {
      resourcesList.classList.toggle(this.WIDE_MODE_CLASS);

      var switchButton = resourcesList.querySelector(".js-resource-list-switch-view-button");

      if (switchButton) {
        var switchButtonIcon = switchButton.querySelector("i");

        switchButtonIcon.classList.toggle("fa-grip-vertical");
        switchButtonIcon.classList.toggle("fa-bars");

        var isNowWide = this.isResourcesListInWideMode(resourcesList);
        var newLabel = isNowWide ? switchButton.dataset.labelToTile : switchButton.dataset.labelToList;

        switchButton.setAttribute("title", newLabel);
        switchButton.setAttribute("aria-label", newLabel);
      }
    }
  };
}).call(this);

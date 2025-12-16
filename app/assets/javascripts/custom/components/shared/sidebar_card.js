(function() {
  "use strict";
  App.SidebarCardComponent = {
    initialized: false,

    initialize: function() {
      if (this.initialized) {
        return;
      }

      $(document).on("click", ".js-sidebar-card--title", this.toggleContent.bind(this));

      this.initialized = true;
    },

    toggleContent: function(e) {
      var $sidebarCard = $(e.currentTarget.closest(".sidebar-card"));

      if (window.innerWidth <= 970) {
        var $content = $sidebarCard.find(".sidebar-card--content");
        $content.toggle();
        $sidebarCard.find(".icon-chevron-down").toggleClass("-rotated");
      }

      this.reInitializeMap();
    },

    reInitializeMap: function() {
      const sidebarCard = event.target.closest(".sidebar-card")
      const $mapContainer = $(sidebarCard).find("*[data-map]:visible");

      if ($mapContainer.length === 0) { return; }

      App.Map.destroyMapForElementId($mapContainer.attr("id"));
      App.Map.initializeMapForElementId($mapContainer.attr("id"));
    }
  };
}).call(this);


(function() {
  "use strict";

  const MOBILE_TOGGLE_MAX_WIDTH = 970;

  App.SidebarCardComponent = {
    initialized: false,

    initialize: function() {
      if (this.initialized) {
        return;
      }

      $(document).on("click", ".js-sidebar-card--title", this.toggleContent.bind(this));
      $(window).on("resize", this.updateTitlesFocusability.bind(this));

      this.updateTitlesFocusability();

      this.initialized = true;
    },

    updateTitlesFocusability: function() {
      const isInert = window.innerWidth > MOBILE_TOGGLE_MAX_WIDTH;

      document.querySelectorAll(".js-sidebar-card--title").forEach((title) => {
        if (isInert) {
          title.setAttribute("tabindex", "-1");
        } else {
          title.removeAttribute("tabindex");
        }
      });
    },

    toggleContent: function(e) {
      var $sidebarCard = $(e.currentTarget.closest(".sidebar-card"));

      if (window.innerWidth <= MOBILE_TOGGLE_MAX_WIDTH) {
        var $content = $sidebarCard.find(".sidebar-card--content");
        $content.toggle();
        $sidebarCard.find(".icon-chevron-down").toggleClass("-rotated");

        var isExpanded = $content.is(":visible");
        $(e.currentTarget).attr("aria-expanded", isExpanded);
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


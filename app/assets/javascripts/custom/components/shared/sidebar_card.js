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
      $(document).on("keydown", ".js-sidebar-card--title", this.handleTitleKeydown.bind(this));
      $(window).on("resize", App.Shared.debounce(this.updateTitlesInteractivity.bind(this), 150));

      this.updateTitlesInteractivity();

      this.initialized = true;
    },

    updateTitlesInteractivity: function() {
      const isMobile = window.innerWidth <= MOBILE_TOGGLE_MAX_WIDTH;

      document.querySelectorAll(".js-sidebar-card--title").forEach((title) => {
        if (isMobile) {
          this.enableTitleAsButton(title);
        } else {
          this.disableTitleAsButton(title);
        }
      });
    },

    enableTitleAsButton: function(title) {
      const expanded = this.isContentExpanded(title);

      title.setAttribute("role", "button");
      title.setAttribute("tabindex", "0");
      title.setAttribute("aria-expanded", expanded);

      $(title.closest(".sidebar-card"))
        .find(".icon-chevron-down")
        .toggleClass("-rotated", expanded === "true");
    },

    disableTitleAsButton: function(title) {
      title.removeAttribute("role");
      title.removeAttribute("tabindex");
      title.removeAttribute("aria-expanded");

      $(title.closest(".sidebar-card"))
        .find(".sidebar-card--content").css("display", "").end()
        .find(".icon-chevron-down").removeClass("-rotated");
    },

    isContentExpanded: function(title) {
      var $content = $(title.closest(".sidebar-card")).find(".sidebar-card--content");

      return $content.is(":visible") ? "true" : "false";
    },

    handleTitleKeydown: function(e) {
      if (e.key === "Enter" || e.key === " " || e.key === "Spacebar") {
        e.preventDefault();
        this.toggleContent(e);
      }
    },

    toggleContent: function(e) {
      var sidebarCard = e.currentTarget.closest(".sidebar-card");
      var $sidebarCard = $(sidebarCard);

      if (window.innerWidth <= MOBILE_TOGGLE_MAX_WIDTH) {
        var $content = $sidebarCard.find(".sidebar-card--content");
        $content.toggle();
        $sidebarCard.find(".icon-chevron-down").toggleClass("-rotated");

        var isExpanded = $content.is(":visible");
        $(e.currentTarget).attr("aria-expanded", isExpanded);
      }

      this.reInitializeMap(sidebarCard);
    },

    reInitializeMap: function(sidebarCard) {
      const $mapContainer = $(sidebarCard).find("*[data-map]:visible");

      if ($mapContainer.length === 0) { return; }

      App.Map.destroyMapForElementId($mapContainer.attr("id"));
      App.Map.initializeMapForElementId($mapContainer.attr("id"));
    }
  };
}).call(this);


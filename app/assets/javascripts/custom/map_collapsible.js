(function() {
  "use strict";

  App.MapCollapsible = {
    initialize() {
      if (this.listenerBound) return;

      this.listenerBound = true;
      document.addEventListener("toggle", this.handleToggle.bind(this), true);
    },

    handleToggle(event) {
      const details = event.target;

      if (!details.classList) return;
      if (!details.classList.contains("js-map-collapsible")) return;
      if (!details.open) return;

      const mapElement = details.querySelector("[data-map]");

      if (!mapElement) return;

      if (this.isInitialized(mapElement)) {
        this.refreshSize(mapElement);
      } else {
        App.Map.refreshMapsIn(details);
      }
    },

    isInitialized(mapElement) {
      return App.Map.maps.some((instance) => instance.element === mapElement);
    },

    refreshSize(mapElement) {
      const instance = App.Map.maps.find((mapInstance) => mapInstance.element === mapElement);

      if (!instance) return;
      if (!instance.map) return;
      if (!instance.map.invalidateSize) return;

      setTimeout(() => instance.map.invalidateSize(), 50);
    }
  };
}).call(this);

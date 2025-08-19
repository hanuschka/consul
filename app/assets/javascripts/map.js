(function() {
  "use strict";
  App.Map = {
    maps: [],
    initialize: function() {
      $("*[data-map]:visible").each(function() {
        if (  this.classList.contains("leaflet")) {
          App.Map.initializeLeafletMap(this);
        }
      });
    },

    initializeLeafletMap: function(element) {
      const mapInstance = new App.LeafletMapController(element);
      this.maps.push(mapInstance);

      return mapInstance;
    }
  };
}).call(this);

(function() {
  "use strict";
  App.Map = {
    maps: [],
    initialize: function() {
      $("*[data-map]:visible").each(function() {
        if ( this.classList.contains("leaflet")) {
          App.Map.initializeLeafletMap(this);
        } else if ( this.classList.contains("mapbox")) {
          App.Map.initializeMapboxMap(this);
        }
      });
    },

    initializeLeafletMap: function(element) {
      const mapInstance = new App.LeafletMapController(element);
      this.maps.push(mapInstance);

      return mapInstance;
    },

    initializeMapboxMap: function(element) {
      const mapInstance = new App.MapboxMapController(element);
      this.maps.push(mapInstance);

      return mapInstance;
    }
  };
}).call(this);

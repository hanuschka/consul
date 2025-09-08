(function() {
  "use strict";
  App.Map = {
    maps: [],
    initialize: function() {
      $("*[data-map]:visible").each(function() {
        var mapInstance = null;

        for (var i = 0; i < App.Map.maps.length; i++) {
          if (App.Map.maps[i].element.id === this.id ) {
            mapInstance = App.Map.maps[i];
            break;
          }
        }

        if ( mapInstance && this.dataset.placement == 'sidebar' ) {
          return;
        }

        if (mapInstance) {
          mapInstance.map.off();
          mapInstance.map.remove();
          App.Map.maps = App.Map.maps.filter(function(m) {
            return m !== mapInstance;
          });
        }

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

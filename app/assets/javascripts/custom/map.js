(function() {
  "use strict";

  App.Map = {
    instances: [],

    initialize() {
      $("*[data-map]:visible").each((_index, element) => {
        this.initializeLeafletMap(element);
      });

      $("[data-mapbox]:visible").each((_index, element) => {
        this.initializeMapboxMap(element)
      });
    },

    initializeMapFor(element) {
      console.log("initializeMapFor", element)

      if (element.hasAttribute('data-map')) {
        this.initializeLeafletMap(element);
      }
      else if (element.hasAttribute('data-mapbox')) {
        this.initializeMapboxMap(element)
      }
    },

    initializeLeafletMap(element) {
      const mapInstance = new App.LeafletMapController(element);
      this.instances.push(mapInstance)

      return mapInstance
    },

    initializeMapboxMap(element) {
      const mapInstance = new App.MapboxMapController(element);
      this.instances.push(mapInstance)

      return mapInstance
    },

    destroy() {
      App.Map.instances.forEach(function(instance) {
        instance.destroy();
      });
      App.Map.instances = [];
    },

    // Public Interface method for assistant map update and external use
    // DO NOT DELETE
    lastMapSetMarkerTo(lat, lng, shouldScroll) {
      if (App.Map.instances.length > 0) {
        console.log(App.Map.instances[0])
        App.Map.instances[0].setMarkerTo(lat, lng, shouldScroll);
      }
    },

    isCenterMarkerCoordinate(coordinates) {
      return App.Map.isNumeric(coordinates.lat) && App.Map.isNumeric(coordinates.long);
    },

    validCoordinates: function(coordinates) {
      return !isNaN(parseFloat(coordinates.lat)) && !isNaN(parseFloat(coordinates.long));
    },

    isNumeric(n) {
      return !isNaN(parseFloat(n)) && isFinite(n);
    }
  };
}).call(this);


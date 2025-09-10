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
    },

    // shared functions

    setupEventListenersForMarkerStyleChanges(instance) {
      const selectors = document.querySelectorAll(".js-map-change-feature-style");

      if (!selectors) return;

      const updateFeatureVariables = function() {
        const currentlyMarked = document.querySelectorAll(".js-map-change-feature-style.marked");

        if (currentlyMarked.length === 0) {
          instance.featureColor = null;
          instance.featureIconName = null;
          instance.featureIconUnicode = null;
          instance.featureCategoryName = null;

        } else if (currentlyMarked.length > 1) {
          const nodes = Array.prototype.slice.call(currentlyMarked);

          const colorOptions = nodes.map(function(n) { return n.dataset.featureColor }).filter(Boolean);
          const iconNameOptions = nodes.map(function(n) { return n.dataset.featureIconName }).filter(Boolean);
          const iconUnicodeOptions = nodes.map(function(n) { return n.dataset.featureIconUnicode }).filter(Boolean);
          const categoryNameOptions = nodes.map(function(n) { return n.dataset.featureCategoryName }).filter(Boolean);

          instance.featureColor = colorOptions.length === 1 ? colorOptions[0] : null;
          instance.featureIconName = iconNameOptions.length === 1 ? iconNameOptions[0] : 'tags';
          instance.featureIconUnicode = iconUnicodeOptions.length === 1 ? iconUnicodeOptions[0] : 'f02c';
          instance.featureCategoryName = null;

        } else if (currentlyMarked.length === 1) {
          const el = currentlyMarked[0];

          instance.featureColor = el.dataset.featureColor || null
          instance.featureIconName = el.dataset.featureIconName  || null
          instance.featureIconUnicode = el.dataset.featureIconUnicode || null
          instance.featureCategoryName = el.dataset.featureCategoryName || null
        }


        if (instance.constructor.name === 'LeafletMapController') {
          instance.map.pm.setGlobalOptions({
            markerStyle: {
              icon: App.Utils.getLeafletMarkerHTML(instance.featureColor || instance.defaultFeatureColor, instance.featureIconName || 'circle'),
            }
          });
        }
      }

      updateFeatureVariables();

      selectors.forEach(function(selector) {
        selector.addEventListener("click", function() {
          if (this.dataset.featureMultipleAllowed === "true") {
            this.classList.toggle('marked');
          } else {
            this.parentElement.querySelectorAll(".js-map-change-feature-style").forEach(function(s) {
              s.classList.remove('marked');
            });
            this.classList.add('marked');
          }
          updateFeatureVariables();
        });
      });
    }


  };
}).call(this);

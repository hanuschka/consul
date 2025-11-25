(function() {
  "use strict";
  App.Map = {
    maps: [],
    initialize: function() {
      $("*[data-map]:visible").each(function() {
        App.Map.destroyMapForElementId(this.id);
        App.Map.initializeMapForElementId(this.id);
      });
    },

    destroyMapForElementId: function(elementId) {
      var mapInstance = null;

      for (var i = 0; i < App.Map.maps.length; i++) {
        if (App.Map.maps[i].element.id === elementId ) {
          mapInstance = App.Map.maps[i];
          break;
        }
      }

      if (mapInstance) {
        mapInstance.map.off();
        mapInstance.map.remove();
        App.Map.maps = App.Map.maps.filter(function(m) {
          return m !== mapInstance;
        });
      }
    },

    initializeMapForElementId: function(elementId) {
      const element = document.getElementById(elementId);

      if ( element.classList.contains("leaflet")) {
        App.Map.initializeLeafletMap(element);
      } else if ( element.classList.contains("mapbox")) {
        App.Map.initializeMapboxMap(element);
      } else if ( element.classList.contains("virtualcity")) {
        App.Map.initializeVirtualcityMap(element);
      }
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

    initializeVirtualcityMap: function(element) {
      const mapInstance = new App.VirtualcityMapController(element);
      this.maps.push(mapInstance);

      return mapInstance;
    },

    anyMapInitialized() {
      return App.Map.maps.length > 0
    },

    // Public Interface method for assistant map update and external use
    // DO NOT DELETE
    setMarkerTo(lat, lng, shouldScroll) {
      if (App.Map.anyMapInitialized()) {
        App.Map.maps[0].setMarkerTo(lat, lng, shouldScroll);
      }
    },

    // shared functions

    formattedFeatures(input) {
      if (Array.isArray(input)) {
        let merged = {
          type: 'FeatureCollection',
          id: 'formatted-features',
          features: []
        };

        input.forEach(function(resource_features) {
          if (resource_features && resource_features.type === 'FeatureCollection' && Array.isArray(resource_features.features)) {
            Array.prototype.push.apply(merged.features, resource_features.features);
          } else if (resource_features && resource_features.type === 'Feature' && resource_features.geometry) {
            merged.features.push(resource_features);
          }
        });

        return merged;
      } else if (input && input.type === 'FeatureCollection') {
        return input;
      } else if (input && input.type === 'Feature' && input.geometry) {
        return {
          type: 'FeatureCollection',
          id: 'formatted-features',
          features: [input]
        };
      } else {
        return {
          type: 'FeatureCollection',
          id: 'formatted-features',
          features: []
        }
      }
    },

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

        if (instance.element.classList.contains("leaflet")) {
          instance.map.pm.setGlobalOptions({
            markerStyle: {
              icon: App.Utils.getLeafletMarkerHTML(instance.featureColor || instance.defaultFeatureColor, instance.featureIconName || 'circle'),
            }
          });
        }
      }

      const updateFeatureVariablesFromSelectOption = function(option) {
        if (option.dataset.featureColor) {
          instance.featureColor = option.dataset.featureColor;
        }

        if (option.dataset.featureIconName) {
          instance.featureIconName = option.dataset.featureIconName;
        }

        if (option.dataset.featureIconUnicode) {
          instance.featureIconUnicode = option.dataset.featureIconUnicode;
        }

        if (option.dataset.featureCategoryName) {
          instance.featureCategoryName = option.dataset.featureCategoryName;
        }

        if (instance.element.classList.contains("leaflet")) {
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

      document.querySelectorAll(".js-map-change-feature-style-on-select").forEach(function(selector) {
        selector.addEventListener("change", function() {
          const value = this.value;
          if (!value) return;

          const option = this.querySelector(`option[value='${value}']`);
          if (!option) return;

          updateFeatureVariablesFromSelectOption(option);
        });

        const currentValue = selector.value;
        const currentOption = selector.querySelector(`option[value='${currentValue}']`);

        if (!currentOption) return;

        updateFeatureVariablesFromSelectOption(currentOption);
      });
    }
  };
}).call(this);

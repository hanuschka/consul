(function() {
  "use strict";
  App.Map = {
    maps: [],

    // Parse a style value to a finite number, falling back to a default for blank
    // ("") / null / non-numeric input (form fields submit "" when left empty).
    numberOrDefault: function(value, fallback) {
      var parsed = parseFloat(value);
      return isNaN(parsed) ? fallback : parsed;
    },

    initialize: function() {
      $("*[data-map]:visible").each(function() {
        App.Map.destroyMapForElementId(this.id);
        App.Map.initializeMapForElementId(this.id);
      });
    },

    destroy: function() {
      App.Map.maps.forEach(function(mapInstance) {
        if (mapInstance.map) {
          mapInstance.map.off();
          mapInstance.map.remove();
        }
      });
      App.Map.maps = [];
    },

    refreshMapsIn: function(container) {
      var $container = $(container);

      $container.find('[data-map]').each(function() {
        App.Map.destroyMapForElementId(this.id);
        App.Map.initializeMapForElementId(this.id);
      });

      var containerEl = $container[0];

      setTimeout(function() {
        App.Map.maps.forEach(function(mapInstance) {
          if (containerEl.contains(mapInstance.element) && mapInstance.map && mapInstance.map.invalidateSize) {
            mapInstance.map.invalidateSize();
          }
        });
      }, 150);
    },

    bindEscToCollapseExpanded: function() {
      if (App.Map.escCollapseBound) return;

      App.Map.escCollapseBound = true;

      document.addEventListener("keydown", function(event) {
        if (event.key !== "Escape" && event.keyCode !== 27) return;

        var expanded = document.querySelector(".map_location.expanded");

        if (!expanded) return;

        var instance = App.Map.maps.find(function(mapInstance) {
          return mapInstance.element === expanded;
        });

        if (instance && instance.collapseMap) {
          instance.collapseMap();
        }
      });
    },

    invalidateSizeIn: function(container) {
      var containerEl = $(container)[0];

      if (!containerEl) return;

      App.Map.maps.forEach(function(mapInstance) {
        if (containerEl.contains(mapInstance.element) && mapInstance.map && mapInstance.map.invalidateSize) {
          mapInstance.map.invalidateSize();
        }
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
        if ( mapInstance.constructor.name === "LeafletMapController" ) {
          mapInstance.map.off();
          mapInstance.map.remove();
        } else if ( mapInstance.constructor.name === "MapboxMapController" ) {
          mapInstance.map.off();
          mapInstance.map.remove();
        }

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
      App.Map.loadMapDataFromUrl(mapInstance);

      return mapInstance;
    },

    initializeMapboxMap: function(element) {
      const mapInstance = new App.MapboxMapController(element);
      this.maps.push(mapInstance);
      App.Map.loadMapDataFromUrl(mapInstance);

      return mapInstance;
    },

    initializeVirtualcityMap: function(element) {
      const mapInstance = new App.VirtualcityMapController(element);
      this.maps.push(mapInstance);
      App.Map.loadMapDataFromUrl(mapInstance);

      return mapInstance;
    },

    loadMapDataFromUrl: function(mapInstance) {
      const $element = $(mapInstance.element);
      const url = $element.data("map-data-url");

      if (!url) return;

      const $wrapper = $element.closest(".js-map-data-wrapper");

      App.Ajax
        .get(url)
        .then(function(data) {
          mapInstance.features = data;
          mapInstance.renderFeatures();
          App.Map.hideMapDataOverlay($wrapper);
        })
        .catch(function() {
          App.Map.showMapDataOverlayError($wrapper);
        });
    },

    hideMapDataOverlay: function($wrapper) {
      $wrapper.find(".js-map-data-overlay").addClass("-hidden");
    },

    showMapDataOverlayError: function($wrapper) {
      $wrapper
        .find(".js-map-data-overlay")
        .removeClass("-loading -hidden")
        .addClass("-error");
    },

    showMapDataOverlayLoading: function($wrapper) {
      $wrapper
        .find(".js-map-data-overlay")
        .removeClass("-hidden -error")
        .addClass("-loading");
    },

    retryMapDataLoad: function($retryButton) {
      const $wrapper = $retryButton.closest(".js-map-data-wrapper");
      const elementId = $wrapper.find("[data-map]").attr("id");
      const mapInstance = App.Map.maps.find(function(m) {
        return m.element.id === elementId;
      });

      if (!mapInstance) return;

      App.Map.showMapDataOverlayLoading($wrapper);
      App.Map.loadMapDataFromUrl(mapInstance);
    },

    anyMapInitialized() {
      return App.Map.maps.length > 0
    },

    // Public Interface method for assistant map update and external use
    // DO NOT DELETE
    setMarkerTo(lat, lng, shouldScroll) {
      if (App.Map.maps.length > 0) {
        App.Map.maps[0].setMarkerTo(lat, lng, shouldScroll);
      }
    },

    // shared functions

    splitMasterportalFeatures(input) {
      const collection = App.Map.formattedFeatures(input);

      const masterportal = {
        type: "FeatureCollection",
        id: "masterportal-pin-features",
        features: []
      };
      const regular = {
        type: "FeatureCollection",
        id: "regular-features",
        features: []
      };

      collection.features.forEach(function(feature) {
        if (feature && feature.properties && feature.properties.resource_type === "masterportal_pin") {
          masterportal.features.push(feature);
        } else {
          regular.features.push(feature);
        }
      });

      return { regular: regular, masterportal: masterportal };
    },

    formattedFeatures(input) {
      let items;

      if (Array.isArray(input)) {
        items = input;
      } else if (input && input.type === 'FeatureCollection' && Array.isArray(input.features)) {
        items = input.features;
      } else if (input && input.type === 'Feature' && input.geometry) {
        items = [input];
      } else {
        items = [];
      }

      const merged = {
        type: 'FeatureCollection',
        id: 'formatted-features',
        features: []
      };

      items.forEach(function(item) {
        if (item && item.type === 'FeatureCollection' && Array.isArray(item.features)) {
          Array.prototype.push.apply(merged.features, item.features);
        } else if (item && item.type === 'Feature' && item.geometry) {
          merged.features.push(item);
        }
      });

      return merged;
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
            const clicked = this;

            clicked.parentElement.querySelectorAll(".js-map-change-feature-style").forEach(function(s) {
              s.classList.remove('marked');

              if (s !== clicked) {
                const checkbox = document.getElementById(s.htmlFor);

                if (checkbox && checkbox.type === "checkbox") {
                  checkbox.checked = false;
                }
              }
            });
            clicked.classList.add('marked');
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

  $(document).on("click", ".js-map-data-retry", function() {
    App.Map.retryMapDataLoad($(this));
  });
}).call(this);

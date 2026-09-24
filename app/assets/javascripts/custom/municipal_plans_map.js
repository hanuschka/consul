(function() {
  "use strict";

  var AREAS_SOURCE_ID = "municipal-plans-areas";
  var AREAS_FILL_LAYER_ID = "municipal-plans-areas-fill";
  var AREAS_LINE_LAYER_ID = "municipal-plans-areas-line";
  var MARKER_LIFT = 10;
  var FIT_PADDING = 20;
  var MAP_WAIT_INTERVAL = 50;
  var MAP_WAIT_ATTEMPTS = 200;

  App.MunicipalPlansMap = {
    initialize: function() {
      document.querySelectorAll(".js-municipal-plans-map").forEach(function(wrapper) {
        App.MunicipalPlansMap.setup(wrapper);
      });
    },

    setup: function(wrapper) {
      var container = wrapper.querySelector("[data-map]");
      if (!container) {
        return;
      }

      var instance = App.MunicipalPlansMap.mapInstanceFor(container);
      if (!instance || instance.municipalPlansMapBound) {
        return;
      }

      var areas = App.MunicipalPlansMap.parseCollection(wrapper.dataset.areas);
      if (areas.features.length === 0) {
        return;
      }

      var markers = App.MunicipalPlansMap.parseCollection(wrapper.dataset.markers);

      instance.municipalPlansMapBound = true;

      var renderer = container.classList.contains("mapbox") ?
        App.MunicipalPlansMap.mapbox : App.MunicipalPlansMap.leaflet;

      App.MunicipalPlansMap.whenMapReady(instance, function(map) {
        renderer.render(map, areas, markers);
      });
    },

    mapInstanceFor: function(container) {
      var maps = (App.Map && App.Map.maps) || [];

      return maps.filter(function(instance) {
        return instance.element === container;
      })[0];
    },

    whenMapReady: function(instance, callback) {
      if (instance.map) {
        callback(instance.map);
        return;
      }

      var attempts = 0;

      var timer = setInterval(function() {
        attempts += 1;

        var registered = ((App.Map && App.Map.maps) || []).indexOf(instance) !== -1;

        if (!registered || attempts >= MAP_WAIT_ATTEMPTS) {
          clearInterval(timer);
        } else if (instance.map) {
          clearInterval(timer);
          callback(instance.map);
        }
      }, MAP_WAIT_INTERVAL);
    },

    parseCollection: function(value) {
      var empty = { type: "FeatureCollection", features: [] };

      try {
        var collection = JSON.parse(value || "null");

        return collection && Array.isArray(collection.features) ? collection : empty;
      } catch (error) {
        return empty;
      }
    },

    toggleDistrict: function(districtId) {
      if (districtId === undefined || districtId === null) {
        return;
      }

      var checkbox = document.getElementById("filter_district_" + districtId);
      if (!checkbox) {
        return;
      }

      checkbox.dataset.skipFocusRestore = "true";
      checkbox.click();
    },

    escapeHtml: function(value) {
      return String(value === undefined || value === null ? "" : value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
    },

    popupHtml: function(properties) {
      var escape = App.MunicipalPlansMap.escapeHtml;

      return "<a href=\"" + escape(properties.url) + "\">" + escape(properties.title) + "</a>";
    },

    colors: function() {
      return { brand: App.Utils.getBrandColor() };
    },

    leaflet: {
      render: function(map, areas, markers) {
        var brand = App.MunicipalPlansMap.colors().brand;

        var areasLayer = L.geoJSON(areas, {
          style: function(feature) {
            var selected = feature.properties && feature.properties.selected === true;

            return {
              color: brand,
              weight: selected ? 3 : 1,
              fillColor: brand,
              fillOpacity: selected ? 0.45 : 0.1
            };
          },
          onEachFeature: function(feature, layer) {
            var properties = feature.properties || {};

            layer.bindTooltip(App.MunicipalPlansMap.escapeHtml(properties.name), { sticky: true });

            layer.on("click", function() {
              App.MunicipalPlansMap.toggleDistrict(properties.district_id);
            });
          }
        }).addTo(map);

        markers.features.forEach(function(feature) {
          var coordinates = feature.geometry && feature.geometry.coordinates;
          if (!coordinates) {
            return;
          }

          var properties = feature.properties || {};
          var title = App.MunicipalPlansMap.escapeHtml(properties.title);

          L.marker([coordinates[1], coordinates[0]], {
            icon: App.Utils.getLeafletMarkerHTML(null, null, title)
          })
            .bindPopup(App.MunicipalPlansMap.popupHtml(properties), { offset: L.point(0, -30) })
            .addTo(map);
        });

        var bounds = areasLayer.getBounds();

        if (bounds.isValid()) {
          map.fitBounds(bounds, { padding: [FIT_PADDING, FIT_PADDING] });
        }
      }
    },

    mapbox: {
      render: function(map, areas, markers) {
        if (!map.isStyleLoaded()) {
          map.once("idle", function() {
            App.MunicipalPlansMap.mapbox.render(map, areas, markers);
          });

          return;
        }

        if (map.getSource(AREAS_SOURCE_ID)) {
          return;
        }

        var brand = App.MunicipalPlansMap.colors().brand;
        var selected = ["==", ["get", "selected"], true];

        map.addSource(AREAS_SOURCE_ID, { type: "geojson", data: areas });

        map.addLayer({
          id: AREAS_FILL_LAYER_ID,
          type: "fill",
          source: AREAS_SOURCE_ID,
          paint: {
            "fill-color": brand,
            "fill-opacity": ["case", selected, 0.45, 0.1]
          }
        });

        map.addLayer({
          id: AREAS_LINE_LAYER_ID,
          type: "line",
          source: AREAS_SOURCE_ID,
          paint: {
            "line-color": brand,
            "line-width": ["case", selected, 3, 1]
          }
        });

        App.MunicipalPlansMap.mapbox.bindAreaEvents(map);
        App.MunicipalPlansMap.mapbox.addMarkers(map, markers);
        App.MunicipalPlansMap.mapbox.fitToAreas(map, areas);
      },

      bindAreaEvents: function(map) {
        var namePopup = new window.mapboxgl.Popup({ closeButton: false, closeOnClick: false });

        map.on("mousemove", AREAS_FILL_LAYER_ID, function(event) {
          var feature = event.features && event.features[0];
          if (!feature) {
            return;
          }

          map.getCanvas().style.cursor = "pointer";

          namePopup
            .setLngLat(event.lngLat)
            .setHTML(App.MunicipalPlansMap.escapeHtml(feature.properties.name))
            .addTo(map);
        });

        map.on("mouseleave", AREAS_FILL_LAYER_ID, function() {
          map.getCanvas().style.cursor = "";
          namePopup.remove();
        });

        map.on("click", AREAS_FILL_LAYER_ID, function(event) {
          var target = event.originalEvent && event.originalEvent.target;
          if (target && target.closest && target.closest(".mapboxgl-marker, .mapboxgl-popup")) {
            return;
          }

          var feature = event.features && event.features[0];
          if (!feature) {
            return;
          }

          App.MunicipalPlansMap.toggleDistrict(feature.properties.district_id);
        });
      },

      addMarkers: function(map, markers) {
        markers.features.forEach(function(feature) {
          var coordinates = feature.geometry && feature.geometry.coordinates;
          if (!coordinates) {
            return;
          }

          var properties = feature.properties || {};

          var popup = new window.mapboxgl.Popup({ offset: 30 })
            .setHTML(App.MunicipalPlansMap.popupHtml(properties));

          new window.mapboxgl.Marker({
            element: App.MunicipalPlansMap.mapbox.markerElement(properties.title),
            anchor: "bottom",
            offset: [0, -MARKER_LIFT]
          })
            .setLngLat([coordinates[0], coordinates[1]])
            .setPopup(popup)
            .addTo(map);
        });
      },

      markerElement: function(title) {
        var element = document.createElement("div");
        element.className = "map-marker";

        var icon = document.createElement("div");
        icon.className = "map-icon icon-circle";
        icon.style.backgroundColor = App.Utils.getBrandColor();
        icon.setAttribute("role", "img");
        icon.setAttribute("aria-label", title || "");
        element.appendChild(icon);

        return element;
      },

      fitToAreas: function(map, areas) {
        var bounds = { minLng: Infinity, minLat: Infinity, maxLng: -Infinity, maxLat: -Infinity };

        var extend = function(coordinates) {
          if (!Array.isArray(coordinates)) {
            return;
          }

          if (typeof coordinates[0] === "number") {
            bounds.minLng = Math.min(bounds.minLng, coordinates[0]);
            bounds.minLat = Math.min(bounds.minLat, coordinates[1]);
            bounds.maxLng = Math.max(bounds.maxLng, coordinates[0]);
            bounds.maxLat = Math.max(bounds.maxLat, coordinates[1]);
            return;
          }

          coordinates.forEach(extend);
        };

        areas.features.forEach(function(feature) {
          extend(feature.geometry && feature.geometry.coordinates);
        });

        if (!isFinite(bounds.minLng)) {
          return;
        }

        map.fitBounds(
          [[bounds.minLng, bounds.minLat], [bounds.maxLng, bounds.maxLat]],
          { padding: FIT_PADDING, duration: 0 }
        );
      }
    }
  };
}).call(this);

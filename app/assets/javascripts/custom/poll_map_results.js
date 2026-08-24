(function() {
  "use strict";

  var SOURCE_ID = "poll-map-results-heat";
  var MAP_WAIT_INTERVAL = 50;
  var MAP_WAIT_ATTEMPTS = 200;

  App.PollMapResults = {
    initialize: function() {
      document.querySelectorAll(".js-poll-map-results").forEach(function(wrapper) {
        App.PollMapResults.setup(wrapper);
      });
    },

    setup: function(wrapper) {
      var container = wrapper.querySelector("[data-map]");
      if (!container) return;

      var instance = App.PollMapResults.mapInstanceFor(container);
      if (!instance || instance.pollMapResultsBound) return;

      var points = App.PollMapResults.parsePoints(wrapper.dataset.heatPoints);
      if (points.length === 0) return;

      instance.pollMapResultsBound = true;

      var render = container.classList.contains("mapbox") ?
        App.PollMapResults.renderMapbox : App.PollMapResults.renderLeaflet;

      App.PollMapResults.whenMapReady(instance, function(map) {
        render(map, points);
      });
    },

    mapInstanceFor: function(container) {
      var maps = (App.Map && App.Map.maps) || [];

      return maps.filter(function(instance) {
        return instance.element === container;
      })[0];
    },

    // Leaflet builds its map in the constructor; Mapbox only after its scripts
    // have loaded, so the instance can be registered before it has a map.
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

    parsePoints: function(value) {
      try {
        return JSON.parse(value || "[]");
      } catch (error) {
        return [];
      }
    },

    renderLeaflet: function(map, points) {
      if (typeof L === "undefined" || typeof L.heatLayer !== "function") return;

      L.heatLayer(points, { radius: 25, blur: 20, maxZoom: 17 }).addTo(map);
    },

    renderMapbox: function(map, points) {
      if (!map.isStyleLoaded()) {
        map.once("idle", function() {
          App.PollMapResults.renderMapbox(map, points);
        });

        return;
      }

      if (map.getSource(SOURCE_ID)) return;

      map.addSource(SOURCE_ID, {
        type: "geojson",
        data: {
          type: "FeatureCollection",
          features: points.map(function(point) {
            return {
              type: "Feature",
              properties: {},
              geometry: { type: "Point", coordinates: [point[1], point[0]] }
            };
          })
        }
      });

      map.addLayer({
        id: SOURCE_ID,
        type: "heatmap",
        source: SOURCE_ID,
        paint: {
          // Mirrors leaflet.heat's default blue/lime/red ramp so both libraries
          // read the same. Density 0 must stay transparent or the whole map tints.
          "heatmap-color": [
            "interpolate", ["linear"], ["heatmap-density"],
            0, "rgba(0, 0, 255, 0)",
            0.4, "rgba(0, 0, 255, 0.6)",
            0.65, "rgba(0, 255, 0, 0.7)",
            1, "rgba(255, 0, 0, 0.85)"
          ],
          "heatmap-radius": ["interpolate", ["linear"], ["zoom"], 0, 12, 17, 25],
          "heatmap-intensity": ["interpolate", ["linear"], ["zoom"], 0, 1, 17, 3],
          "heatmap-opacity": 0.9
        }
      });
    }
  };
}).call(this);

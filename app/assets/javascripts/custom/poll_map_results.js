(function() {
  "use strict";

  App.PollMapResults = {
    initialize: function() {
      document.querySelectorAll(".js-poll-map-results").forEach(function(wrapper) {
        App.PollMapResults.setup(wrapper);
      });
    },

    setup: function(wrapper) {
      var container = wrapper.querySelector("[data-map]");
      if (!container || typeof L.heatLayer !== "function") return;

      var instance = App.PollMapResults.mapInstanceFor(container);
      if (!instance || !instance.map || instance.pollMapResultsBound) return;

      instance.pollMapResultsBound = true;

      var points = App.PollMapResults.parsePoints(wrapper.dataset.heatPoints);
      if (points.length === 0) return;

      L.heatLayer(points, { radius: 25, blur: 20, maxZoom: 17 }).addTo(instance.map);
    },

    mapInstanceFor: function(container) {
      var maps = (App.Map && App.Map.maps) || [];

      return maps.filter(function(instance) {
        return instance.element === container;
      })[0];
    },

    parsePoints: function(value) {
      try {
        return JSON.parse(value || "[]");
      } catch (error) {
        return [];
      }
    }
  };
}).call(this);

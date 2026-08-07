(function() {
  "use strict";

  App.HeatmapComponent = {
    initialize: function() {
      const maps = document.querySelectorAll("[data-heatmap]");
      maps.forEach(this.initMap.bind(this));
    },

    initMap: function(container) {
      if (container.dataset.heatmapInitialized === "true") {
        return;
      }

      const coordinates = JSON.parse(container.dataset.heatmapCoordinates || "[]");
      const center = JSON.parse(container.dataset.heatmapCenter || "[51.505, -0.09]");
      const zoom = parseInt(container.dataset.heatmapZoom || "12", 10);

      if (coordinates.length === 0) {
        container.innerHTML = "<p style='text-align:center;padding:40px;color:#666;'>Keine Standortdaten verfügbar</p>";
        return;
      }

      const zoomLimits = App.MapZoom;

      const map = L.map(container, {
        gestureHandling: true,
        zoomControl: true,
        maxZoom: zoomLimits.MAX
      }).setView(center, zoom);

      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
        maxZoom: zoomLimits.MAX,
        maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
      }).addTo(map);

      const boostedCoordinates = coordinates.map((coord) => {
        return [coord[0], coord[1], 1];
      });

      const heatOptions = {
        radius: 40,
        blur: 22,
        minOpacity: 0.45,
        max: 1.0,
        gradient: {
          0.0: "rgba(0, 150, 255, 0.7)",
          0.3: "rgba(0, 255, 200, 0.75)",
          0.5: "rgba(255, 255, 0, 0.8)",
          0.7: "rgba(255, 150, 0, 0.85)",
          1.0: "rgba(255, 0, 0, 0.9)"
        }
      };

      if (typeof L.heatLayer === "function") {
        L.heatLayer(boostedCoordinates, heatOptions).addTo(map);
      } else {
        this.loadHeatPlugin(() => {
          L.heatLayer(boostedCoordinates, heatOptions).addTo(map);
        });
      }

      container.dataset.heatmapInitialized = "true";
    },

    loadHeatPlugin: function(callback) {
      if (typeof L.heatLayer === "function") {
        callback();
        return;
      }

      const script = document.createElement("script");
      script.src = "https://unpkg.com/leaflet.heat@0.2.0/dist/leaflet-heat.js";
      script.onload = callback;
      document.head.appendChild(script);
    }
  };
}).call(this);


(function() {
  "use strict";

  var MARKER_LIFT = 10;
  var FIT_PADDING = 20;

  App.OffersMap = {
    maps: [],

    initialize: function() {
      document.querySelectorAll(".js-offers-map .js-offers-map-container").forEach(function(container) {
        App.OffersMap.setup(container);
      });
    },

    destroy: function() {
      App.OffersMap.maps.forEach(function(entry) {
        entry.destroyed = true;

        if (entry.map) {
          entry.map.remove();
        }

        delete entry.container.dataset.initialized;
      });

      App.OffersMap.maps = [];
    },

    setup: function(container) {
      if (container.dataset.initialized === "true") {
        return;
      }

      var markers = App.OffersMap.parseCollection(container.dataset.markers);

      if (markers.features.length === 0) {
        return;
      }

      container.dataset.initialized = "true";

      var entry = { container: container, map: null, destroyed: false };
      App.OffersMap.maps.push(entry);

      var settings = App.OffersMap.settings(container);

      var renderer = settings.library === "mapbox" ? App.OffersMap.mapbox : App.OffersMap.leaflet;

      renderer.create(entry, settings, markers);
    },

    settings: function(container) {
      var data = container.dataset;

      return {
        library: data.library,
        bounds: App.OffersMap.parseJson(data.bounds),
        latitude: parseFloat(data.latitude),
        longitude: parseFloat(data.longitude),
        zoom: parseFloat(data.zoom),
        mapboxToken: data.mapboxToken,
        mapboxStyle: data.mapboxStyle,
        tileLayer: App.OffersMap.parseJson(data.tileLayer)
      };
    },

    parseJson: function(value) {
      try {
        return JSON.parse(value || "null");
      } catch (error) {
        return null;
      }
    },

    parseCollection: function(value) {
      var empty = { type: "FeatureCollection", features: [] };
      var collection = App.OffersMap.parseJson(value);

      return collection && Array.isArray(collection.features) ? collection : empty;
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
      var escape = App.OffersMap.escapeHtml;

      return "<a href=\"" + escape(properties.url) + "\">" + escape(properties.title) + "</a>";
    },

    leaflet: {
      create: function(entry, settings, markers) {
        var map = L.map(entry.container, { gestureHandling: true, zoomControl: true });
        var bounds = settings.bounds;

        entry.map = map;

        if (bounds) {
          map.fitBounds(
            [[bounds.south, bounds.west], [bounds.north, bounds.east]],
            { padding: [FIT_PADDING, FIT_PADDING] }
          );
        } else {
          map.setView([settings.latitude, settings.longitude], settings.zoom);
        }

        App.OffersMap.leaflet.baseLayer(settings.tileLayer).addTo(map);
        App.OffersMap.leaflet.addMarkers(map, markers);
      },

      baseLayer: function(item) {
        var zoomLimits = App.MapZoom;

        if (!item) {
          return L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
            attribution: "&copy; <a href=\"http://osm.org/copyright\">OpenStreetMap</a> contributors",
            maxZoom: zoomLimits.MAX,
            maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
          });
        }

        if (item.protocol === "wms") {
          return L.tileLayer.wms(item.provider, {
            attribution: item.attribution,
            layers: item.layer_names,
            format: (item.transparent ? "image/png" : "image/jpeg"),
            transparent: (item.transparent),
            opacity: (item.opacity ? item.opacity : 1),
            maxZoom: zoomLimits.MAX
          });
        }

        return L.tileLayer(item.provider, {
          attribution: item.attribution,
          maxZoom: zoomLimits.MAX,
          maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
        });
      },

      addMarkers: function(map, markers) {
        markers.features.forEach(function(feature) {
          var coordinates = feature.geometry && feature.geometry.coordinates;
          if (!coordinates) {
            return;
          }

          var properties = feature.properties || {};
          var title = App.OffersMap.escapeHtml(properties.title);

          L.marker([coordinates[1], coordinates[0]], {
            icon: App.Utils.getLeafletMarkerHTML(null, null, title)
          })
            .bindPopup(App.OffersMap.popupHtml(properties), { offset: L.point(0, -30) })
            .addTo(map);
        });
      }
    },

    mapbox: {
      create: function(entry, settings, markers) {
        App.MapboxLoader.load(function() {
          if (entry.destroyed) {
            return;
          }

          var bounds = settings.bounds;
          var options = {
            container: entry.container,
            style: settings.mapboxStyle,
            cooperativeGestures: true,
            locale: {
              "ScrollZoomBlocker.CtrlMessage": "Zum Zoomen der Karte Strg + Scrollen verwenden",
              "ScrollZoomBlocker.CmdMessage": "⌘ gedrückt halten und scrollen, um die Karte zu zoomen",
              "TouchPanBlocker.Message": "Zum Verschieben der Karte zwei Finger verwenden"
            }
          };

          if (bounds) {
            options.bounds = [[bounds.west, bounds.south], [bounds.east, bounds.north]];
            options.fitBoundsOptions = { padding: FIT_PADDING };
          } else {
            options.center = [settings.longitude, settings.latitude];
            options.zoom = settings.zoom;
          }

          window.mapboxgl.accessToken = settings.mapboxToken;

          var map = new window.mapboxgl.Map(options);

          entry.map = map;

          map.addControl(new window.mapboxgl.NavigationControl({ showCompass: false }));

          map.once("load", function() {
            App.OffersMap.mapbox.addMarkers(map, markers);
          });
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
            .setHTML(App.OffersMap.popupHtml(properties));

          new window.mapboxgl.Marker({
            element: App.OffersMap.mapbox.markerElement(properties.title),
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
      }
    }
  };
}).call(this);

(function() {
  "use strict";

  var AREAS_SOURCE_ID = "municipal-plans-areas";
  var AREAS_FILL_LAYER_ID = "municipal-plans-areas-fill";
  var AREAS_LINE_LAYER_ID = "municipal-plans-areas-line";
  var MARKER_LIFT = 10;
  var FIT_PADDING = 20;

  App.MunicipalPlansMap = {
    maps: [],

    initialize: function() {
      document.querySelectorAll(".js-municipal-plans-map .js-municipal-plans-map-container").forEach(function(container) {
        App.MunicipalPlansMap.setup(container);
      });
    },

    destroy: function() {
      App.MunicipalPlansMap.maps.forEach(function(entry) {
        entry.destroyed = true;

        if (entry.map) {
          entry.map.remove();
        }

        delete entry.container.dataset.initialized;
      });

      App.MunicipalPlansMap.maps = [];
    },

    setup: function(container) {
      if (container.dataset.initialized === "true") {
        return;
      }

      var areas = App.MunicipalPlansMap.parseCollection(container.dataset.areas);
      if (areas.features.length === 0) {
        return;
      }

      var markers = App.MunicipalPlansMap.parseCollection(container.dataset.markers);

      container.dataset.initialized = "true";

      var entry = { container: container, map: null, destroyed: false };
      App.MunicipalPlansMap.maps.push(entry);

      var settings = App.MunicipalPlansMap.settings(container);

      var renderer = settings.library === "mapbox" ?
        App.MunicipalPlansMap.mapbox : App.MunicipalPlansMap.leaflet;

      renderer.create(entry, settings, areas, markers);
    },

    settings: function(container) {
      var data = container.dataset;

      return {
        library: data.library,
        bounds: App.MunicipalPlansMap.parseJson(data.bounds),
        latitude: parseFloat(data.latitude),
        longitude: parseFloat(data.longitude),
        zoom: parseFloat(data.zoom),
        mapboxToken: data.mapboxToken,
        mapboxStyle: data.mapboxStyle,
        tileLayer: App.MunicipalPlansMap.parseJson(data.tileLayer)
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
      var collection = App.MunicipalPlansMap.parseJson(value);

      return collection && Array.isArray(collection.features) ? collection : empty;
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
      create: function(entry, settings, areas, markers) {
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

        App.MunicipalPlansMap.leaflet.baseLayer(settings.tileLayer).addTo(map);
        App.MunicipalPlansMap.leaflet.render(map, areas, markers);
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

      render: function(map, areas, markers) {
        var brand = App.MunicipalPlansMap.colors().brand;

        L.geoJSON(areas, {
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
      }
    },

    mapbox: {
      create: function(entry, settings, areas, markers) {
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
            App.MunicipalPlansMap.mapbox.render(map, areas, markers);
          });
        });
      },

      render: function(map, areas, markers) {
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
      }
    }
  };
}).call(this);

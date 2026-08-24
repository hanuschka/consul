(function() {
  "use strict";

  // Leaflet anchors the 30px marker 40px below its top edge, so the circle floats
  // 10px above the actual coordinate. Mapbox markers are offset to match.
  var MARKER_LIFT = 10;
  var MAP_WAIT_INTERVAL = 50;
  var MAP_WAIT_ATTEMPTS = 200;

  App.PollMapPoints = {
    initialize: function() {
      document.querySelectorAll(".js-poll-map-points").forEach(function(wrapper) {
        App.PollMapPoints.setup(wrapper);
      });
    },

    setup: function(wrapper) {
      var container = wrapper.querySelector("[data-map]");
      if (!container) return;

      var instance = App.PollMapPoints.mapInstanceFor(container);
      if (!instance || instance.pollMapPointsBound) return;

      instance.pollMapPointsBound = true;

      App.PollMapPoints.whenMapReady(instance, function(map) {
        App.PollMapPoints.start(wrapper, container, map);
      });
    },

    start: function(wrapper, container, map) {
      var state = {
        wrapper: wrapper,
        map: map,
        renderer: container.classList.contains("mapbox") ? App.PollMapPoints.mapbox : App.PollMapPoints.leaflet,
        maxMapPoints: parseInt(wrapper.dataset.maxMapPoints, 10) || 1,
        canPlace: wrapper.dataset.canPlaceMapPoints === "true",
        features: App.PollMapPoints.parseFeatures(wrapper.dataset.mapPoints)
      };

      state.renderer.create(state);

      App.PollMapPoints.render(state);

      if (!state.canPlace) return;

      state.renderer.bindMapClick(state, function(latitude, longitude) {
        App.PollMapPoints.place(state, latitude, longitude);
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

    leaflet: {
      create: function(state) {
        state.layer = L.layerGroup().addTo(state.map);
      },

      clear: function(state) {
        state.layer.clearLayers();
      },

      addMarker: function(state, latitude, longitude, hint, onRemove) {
        var marker = L.marker([latitude, longitude], {
          icon: App.Utils.getLeafletMarkerHTML(null, null, hint),
          keyboard: true,
          title: hint
        });

        if (onRemove) {
          marker.on("click", function(event) {
            L.DomEvent.stopPropagation(event);
            onRemove();
          });
        }

        marker.addTo(state.layer);
      },

      bindMapClick: function(state, callback) {
        state.map.on("click", function(event) {
          callback(event.latlng.lat, event.latlng.lng);
        });
      }
    },

    mapbox: {
      create: function(state) {
        state.markers = [];
      },

      clear: function(state) {
        state.markers.forEach(function(marker) {
          marker.remove();
        });

        state.markers = [];
      },

      addMarker: function(state, latitude, longitude, hint, onRemove) {
        var element = App.PollMapPoints.markerElement(hint, !!onRemove);

        if (onRemove) {
          element.addEventListener("click", function(event) {
            event.stopPropagation();
            onRemove();
          });

          element.addEventListener("keydown", function(event) {
            if (event.key !== "Enter" && event.key !== " ") return;

            event.preventDefault();
            onRemove();
          });
        }

        var marker = new mapboxgl.Marker({
          element: element,
          anchor: "bottom",
          offset: [0, -MARKER_LIFT]
        }).setLngLat([longitude, latitude]).addTo(state.map);

        state.markers.push(marker);
      },

      bindMapClick: function(state, callback) {
        state.map.on("click", function(event) {
          callback(event.lngLat.lat, event.lngLat.lng);
        });
      }
    },

    markerElement: function(hint, removable) {
      var element = document.createElement("div");
      element.className = "map-marker";

      var icon = document.createElement("div");
      icon.className = "map-icon icon-circle";
      icon.style.backgroundColor = App.Utils.getBrandColor();
      element.appendChild(icon);

      if (removable) {
        element.setAttribute("role", "button");
        element.setAttribute("tabindex", "0");
        element.setAttribute("aria-label", hint);
        element.setAttribute("title", hint);
      } else {
        element.setAttribute("role", "img");
        element.setAttribute("aria-label", hint || "Kartenmarkierung");
      }

      return element;
    },

    parseFeatures: function(value) {
      try {
        return JSON.parse(value || "[]");
      } catch (error) {
        return [];
      }
    },

    render: function(state) {
      state.renderer.clear(state);

      var hint = state.canPlace ? state.wrapper.dataset.removeHintText : null;

      state.features.forEach(function(feature) {
        var coordinates = feature.geometry && feature.geometry.coordinates;
        if (!coordinates) return;

        var mapPointId = feature.properties && feature.properties.id;

        var onRemove = state.canPlace ? function() {
          App.PollMapPoints.remove(state, mapPointId);
        } : null;

        state.renderer.addMarker(state, coordinates[1], coordinates[0], hint, onRemove);
      });

      App.PollMapPoints.updateCounter(state);
      App.PollMapPoints.updateAnsweredState(state);
    },

    updateAnsweredState: function(state) {
      state.wrapper.classList.toggle("js-question-answered", state.features.length > 0);

      if (document.querySelector(".js-question-wizard") && App.QuestionWizard) {
        App.QuestionWizard.mandatoryQuestionActions();
      }
    },

    updateCounter: function(state) {
      var counter = state.wrapper.querySelector(".js-poll-map-points-counter");
      if (!counter) return;

      var remaining = Math.max(state.maxMapPoints - state.features.length, 0);
      var data = state.wrapper.dataset;
      var template;

      if (remaining === 0) {
        template = data.remainingZero;
      } else if (remaining === 1) {
        template = data.remainingOne;
      } else {
        template = data.remainingOther;
      }

      counter.textContent = (template || "").replace("%{count}", remaining);
    },

    setStatus: function(state, message) {
      var status = state.wrapper.querySelector(".js-poll-map-points-status");
      if (status) status.textContent = message || "";
    },

    place: function(state, latitude, longitude) {
      if (state.features.length >= state.maxMapPoints) {
        App.PollMapPoints.setStatus(state, state.wrapper.dataset.limitReachedText);
        return;
      }

      App.PollMapPoints.request(state, state.wrapper.dataset.addMapPointUrl, "POST", {
        latitude: latitude,
        longitude: longitude
      }, state.wrapper.dataset.placedText);
    },

    remove: function(state, mapPointId) {
      if (!mapPointId) return;

      App.PollMapPoints.request(state, state.wrapper.dataset.removeMapPointUrl, "DELETE", {
        map_point_id: mapPointId
      }, state.wrapper.dataset.removedText);
    },

    request: function(state, url, method, payload, successMessage) {
      var token = document.querySelector("meta[name=csrf-token]");

      fetch(url, {
        method: method,
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": token ? token.getAttribute("content") : ""
        },
        body: JSON.stringify(payload)
      }).then(function(response) {
        return response.json().then(function(body) {
          return { ok: response.ok, body: body };
        });
      }).then(function(result) {
        if (!result.ok) {
          App.PollMapPoints.setStatus(state, App.PollMapPoints.errorMessage(state, result.body));
          return;
        }

        state.features = (result.body.features && result.body.features.features) || [];
        App.PollMapPoints.render(state);
        App.PollMapPoints.setStatus(state, successMessage);
      }).catch(function() {
        App.PollMapPoints.setStatus(state, state.wrapper.dataset.errorText);
      });
    },

    errorMessage: function(state, body) {
      var data = state.wrapper.dataset;

      switch (body && body.error) {
        case "outside_boundary":
          return data.outsideBoundaryText;
        case "limit_reached":
          return data.limitReachedText;
        default:
          return data.errorText;
      }
    }
  };
}).call(this);

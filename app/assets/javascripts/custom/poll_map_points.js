(function() {
  "use strict";

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
      if (!instance || !instance.map || instance.pollMapPointsBound) return;

      instance.pollMapPointsBound = true;

      var state = {
        wrapper: wrapper,
        instance: instance,
        layer: L.layerGroup().addTo(instance.map),
        maxMapPoints: parseInt(wrapper.dataset.maxMapPoints, 10) || 1,
        canPlace: wrapper.dataset.canPlaceMapPoints === "true",
        features: App.PollMapPoints.parseFeatures(wrapper.dataset.mapPoints)
      };

      App.PollMapPoints.render(state);

      if (!state.canPlace) return;

      instance.map.on("click", function(event) {
        App.PollMapPoints.place(state, event.latlng);
      });
    },

    mapInstanceFor: function(container) {
      var maps = (App.Map && App.Map.maps) || [];

      return maps.filter(function(instance) {
        return instance.element === container;
      })[0];
    },

    parseFeatures: function(value) {
      try {
        return JSON.parse(value || "[]");
      } catch (error) {
        return [];
      }
    },

    render: function(state) {
      state.layer.clearLayers();

      state.features.forEach(function(feature) {
        var coordinates = feature.geometry && feature.geometry.coordinates;
        if (!coordinates) return;

        var hint = state.canPlace ? state.wrapper.dataset.removeHintText : null;

        var marker = L.marker([coordinates[1], coordinates[0]], {
          icon: App.Utils.getLeafletMarkerHTML(null, null, hint),
          keyboard: true,
          title: hint
        });

        if (state.canPlace) {
          marker.on("click", function(event) {
            L.DomEvent.stopPropagation(event);
            App.PollMapPoints.remove(state, feature.properties && feature.properties.id);
          });
        }

        marker.addTo(state.layer);
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

    place: function(state, latlng) {
      if (state.features.length >= state.maxMapPoints) {
        App.PollMapPoints.setStatus(state, state.wrapper.dataset.limitReachedText);
        return;
      }

      App.PollMapPoints.request(state, state.wrapper.dataset.addMapPointUrl, "POST", {
        latitude: latlng.lat,
        longitude: latlng.lng
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

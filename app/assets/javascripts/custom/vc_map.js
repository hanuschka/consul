(function() {
  "use strict";
  App.VCMap = {
    initialize: function() {
      // $("#vcmap-core").each(function() {
      //   App.Map.initializeMap(this);
      // }
      App.VCMap.initializeMap($("#vcmap-core"))
    },

    initializeMap: function(element) {
      // init App and load a config file
      var vcsApp = new window.vcs.VcsApp();
      vcsApp.maps.setTarget('myMapUUIDnew');
      App.VCMap.loadModule(vcsApp, 'https://new.virtualcitymap.de/map.config.json');

      // create new feature info session to allow feature click interaction
      App.VCMap.createFeatureInfoSession(vcsApp);

      // set cesium base url
      window.CESIUM_BASE_URL = '../dist/assets/cesium/';
      // adding helper instance to window
      window.vcsApp = vcsApp;

      // add base layer
      App.VCMap.createSimpleEditorLayer(vcsApp);
    },

    loadModule: function(app, url, callback) {
      const xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200) {
            const config = JSON.parse(xhr.responseText);
            const module = new window.vcs.VcsModule(config);
            app.addModule(module, function(error) {
              if (error) {
                callback(error);
              } else {
                callback(null, module);
              }
            });
          } else {
            callback(new Error(`Failed to load module from ${url}: ${xhr.status}`));
          }
        }
      };
      xhr.open("GET", url);
      xhr.send();
    },

    createFeatureInfoSession: function(app) {
      /**
       * @class
       * @extends {import("@vcmap/core").AbstractInteraction}
       */

      class CustomFeatureInfoInteraction extends window.vcs.AbstractInteraction {
        /**
         * @param {string} layerName
         */

        constructor(layerName) {
          super(window.vcs.EventType.CLICK, window.vcs.ModificationKeyType.NONE);
          this.layerName = layerName;
          super.setActive();
        }
        /**
         * @param {import("@vcmap/core").InteractionEvent} event
         * @returns {Promise<import("@vcmap/core").InteractionEvent>}
         */

        pipe(event) {
          if (event.feature) {
            // restrict alert to specific layer
            if (event.feature[window.vcs.vcsLayerName] === this.layerName) {
              alert(`The ID of the selected feature is: ${event.feature.getId()}`);
            }
          }
          return event;
        }
      }

      const { eventHandler } = app.maps;
      /** @type {function():void} */
      let stop;
      const interaction = new CustomFeatureInfoInteraction('_demoDrawingLayer');
      const listener = eventHandler.addExclusiveInteraction(
          interaction,
          () => { stop?.(); },
      );
      const currentFeatureInteractionEvent = eventHandler.featureInteraction.active;
      eventHandler.featureInteraction.setActive(window.vcs.EventType.CLICK);

      const stopped = new window.vcs.VcsEvent();
      stop = () => {
        listener();
        interaction.destroy();
        eventHandler.featureInteraction.setActive(currentFeatureInteractionEvent);
        stopped.raiseEvent();
        stopped.destroy();
      }; 

      return {
        stopped,
        stop,
      };
    },

    createSimpleEditorLayer: function(app) {
      const layer = new vcs.VectorLayer({
        name: '_demoDrawingLayer',
        projection: vcs.wgs84Projection.toJSON(),
        zIndex: vcs.maxZIndex - 1,
        vectorProperties: {
          altitudeMode: 'clampToGround'
        }
      });

      // layer style
      const style = new vcs.VectorStyleItem({
        fill: {
            color: '#ff0000',
        },
        stroke: {
            color: '#ffffff',
            width: 1,
        },
        image: {
            color: '#00ff00',
            src: '../dist/assets/cesium/Assets/Textures/pin.svg',
        },
      });
      layer.setStyle(style);

      // layer will not be serialized
      vcs.markVolatile(layer);

      // activate and add layer
      layer.activate();
      app.layers.add(layer);

      const feature = new ol.Feature({ geometry: new ol.geom.Point([13.368109, 52.524500])});
      layer.addFeatures([feature]);

      return layer;
    },

    zoom: function(map, out, zoomFactor) {
      out = typeof out !== 'undefined' ? out : false;
      zoomFactor = typeof zoomFactor !== 'undefined' ? zoomFactor : 2;

      map.getViewpoint().then(function(viewpoint) {
        if (out) {
          viewpoint.distance *= zoomFactor;
        } else {
          viewpoint.distance /= zoomFactor;
        }

        viewpoint.animate = true;
        viewpoint.duration = 0.5;
        viewpoint.cameraPosition = null;
        map.gotoViewpoint(viewpoint);
      });
    },

    setActiveMap: function(maps, mapName) {
      maps.setActiveMap(mapName);
    }
  };
}).call(this);

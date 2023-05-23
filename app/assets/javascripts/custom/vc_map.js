(function() {
  "use strict";
  App.VCMap = {
    initialize: function() {
      document.querySelectorAll("[data-vcmap]").forEach(function(element) {
        App.VCMap.initializeMap(document.querySelector("[data-vcmap]"));
      });
    },

    initializeMap: function(element) {
      // init App and load a config file
      var vcsApp = new window.vcs.VcsApp();
      vcsApp.maps.setTarget(element);
      App.VCMap.loadModule(vcsApp, 'https://new.virtualcitymap.de/map.config.json');

      // custom map options
      vcsApp.customMapOptions = {}
      vcsApp.customMapOptions.editable = $(element).data("editable")
      vcsApp.customMapOptions.latitudeInputSelector = $(element).data("latitude-input-selector");
      vcsApp.customMapOptions.longitudeInputSelector = $(element).data("longitude-input-selector");
      vcsApp.customMapOptions.zoomInputSelector = $(element).data("zoom-input-selector");
      vcsApp.customMapOptions.shapeInputSelector = $(element).data("shape-input-selector");
      vcsApp.customMapOptions.defaultColor = $(element).data("default-color");
      vcsApp.customMapOptions.mapCenterLatitude = $(element).data("map-center-latitude");
      vcsApp.customMapOptions.mapCenterLongitude = $(element).data("map-center-longitude");
      vcsApp.customMapOptions.mapCenterZoom = $(element).data("map-center-zoom");

      // create new feature info session to allow feature click interaction
      App.VCMap.createFeatureInfoSession(vcsApp);

      // set cesium base url
      window.CESIUM_BASE_URL = '../dist3/assets/cesium/';
      // adding helper instance to window
      window.vcsApp = vcsApp;

      // add base layer
      App.VCMap.createSimpleEditorLayer(vcsApp);

      // add predefined shapes
      App.VCMap.drawPredefinedFeatures(vcsApp, element);

      ////// // enable editing new points without having to
      ////// if (vcsApp.customMapOptions.editable) {
      //////   debugger
      //////   App.VCMap.drawFeature(vcsApp, 'Point')
      ////// }

      // set default view
      // vcsApp.maps.added.addEventListener(function(map) {
      //   if ( map.className === 'CesiumMap') {
      //     App.VCMap.setDefaultView(vcsApp);
      //   }
      // });
    },

    loadModule: function(app, url, callback) {
      var xhr = new XMLHttpRequest();
      xhr.onreadystatechange = function() {
        if (xhr.readyState === XMLHttpRequest.DONE) {
          if (xhr.status === 200) {
            var config = JSON.parse(xhr.responseText);
            var module = new window.vcs.VcsModule(config);
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
      function CustomFeatureInfoInteraction(layerName) {
        if (!(this instanceof CustomFeatureInfoInteraction)) {
          throw new TypeError("Cannot call a class as a function");
        }

        window.vcs.AbstractInteraction.call(this, window.vcs.EventType.CLICK, window.vcs.ModificationKeyType.NONE);
        this.layerName = layerName;
        window.vcs.AbstractInteraction.prototype.setActive.call(this);
      }

      CustomFeatureInfoInteraction.prototype = Object.create(window.vcs.AbstractInteraction.prototype);
      CustomFeatureInfoInteraction.prototype.constructor = CustomFeatureInfoInteraction;

      CustomFeatureInfoInteraction.prototype.pipe = function(event) {
        if (event.feature && !vcsApp.editable && event.feature.resource_id) {
          //// // restrict alert to specific layer
          //// if (event.feature[window.vcs.vcsLayerName] === this.layerName) {
          ////   alert('The ID of the selected feature is: ' + event.feature.getId());
          //// }
          App.VCMap.showFeatureInfo(event.feature);
        }
        return event;
      };

      var eventHandler = app.maps.eventHandler;
      var stop;

      var interaction = new CustomFeatureInfoInteraction('_demoDrawingLayer');
      var listener = eventHandler.addExclusiveInteraction(interaction, function() {
                       if (stop) {
                         stop();
                       }
                     });

      var currentFeatureInteractionEvent = eventHandler.featureInteraction.active;
      eventHandler.featureInteraction.setActive(window.vcs.EventType.CLICK);

      var stopped = new window.vcs.VcsEvent();
      stop = function() {
               listener();
               interaction.destroy();
               eventHandler.featureInteraction.setActive(currentFeatureInteractionEvent);
               stopped.raiseEvent();
               stopped.destroy();
             };

      return {
        stopped: stopped,
        stop: stop
      };
    },

    createSimpleEditorLayer: function(app) {
      var layer = new vcs.VectorLayer({
        name: '_demoDrawingLayer',
        projection: vcs.wgs84Projection.toJSON(),
        zIndex: vcs.maxZIndex - 1,
        vectorProperties: {
          altitudeMode: 'absolute'
        }
      });

      // layer style
      var style = new vcs.VectorStyleItem({
        fill: {
          color: app.customMapOptions.defaultColor,
        },
        stroke: {
          color: '#ffffff',
          width: 3,
        },
        image: {
          color: app.customMapOptions.defaultColor,
          src: '../dist3/assets/cesium/Assets/Textures/pin.svg',
          stroke: {
            color: '#ffffff',
            width: 3,
          },
        },
      });
      layer.setStyle(style);

      // layer will not be serialized
      vcs.markVolatile(layer);

      // activate and add layer
      layer.activate();
      app.layers.add(layer);

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
    },

    setDefaultView: function(app) {
      debugger
      var map = app.maps.activeMap;
      var mapCenterLat = app.customMapOptions.mapCenterLatitude;
      var mapCenterLong = app.customMapOptions.mapCenterLongitude;
      var mapCenterZoom = app.customMapOptions.mapCenterZoom;

      var viewpoint = {
        "type": "Viewpoint",
        "name": "Default",
        "cameraPosition": [
          7.628326765047903,
          51.19524414598677,
          567.4244392829526
        ],
        "groundPosition": [
          7.628881118887374,
          51.19874066185536,
          327.79466475129635
        ],
        "distance": 458.54351897275285,
        "heading": 5.688482507076805,
        "pitch": -31.5078138733279,
        "roll": 0.02191005047832281,
        "animate": true
      }

      map.gotoViewpoint(viewpoint);
    },

    drawFeature: function(app, geometryType) {
      event.preventDefault()
      var layer = app.layers.getByKey('_demoDrawingLayer') || App.VCMap.createSimpleEditorLayer(app);
      layer.activate();
      layer.removeAllFeatures();
      var session = vcs.startCreateFeatureSession(app, layer, geometryType);
      // adapt the features style
      var featureCreatedDestroy = session.featureCreated.addEventListener(function(feature) {
        // if (feature.getGeometry() instanceof ol.geom.Point && layer.getFeatures().length > 2) {
        //   var pinStyle = new vcs.VectorStyleItem({});
        //     pinStyle.image = new ol.style.Icon({
        //       color: '#0000ff',
        //       src: '../dist3/assets/cesium/Assets/Textures/pin.svg',
        //       scale: 1,
        //     });
        //   feature.setStyle(pinStyle.style);
        // }
      });
      // to draw only a single feature, stop the session, after creationFinished was fired
      var finishedDestroy = session.creationFinished.addEventListener(function(feature) {
        // convert Mercator coordinates to WGS84
        var geometry = feature.getGeometry();
        if (geometry instanceof ol.geom.Point) {
          var wgs84coordinates = vcs.Projection.mercatorToWgs84(geometry.getCoordinates());

          $(app.customMapOptions.latitudeInputSelector).val(wgs84coordinates[1]);
          $(app.customMapOptions.longitudeInputSelector).val(wgs84coordinates[0]);
          $(app.customMapOptions.zoomInputSelector).val(10); // TODO: fix this line
          $(app.customMapOptions.shapeInputSelector).val(JSON.stringify({}));

        } else if (geometry instanceof ol.geom.Polygon) {
          var coordinates = geometry.getLinearRing(0).getCoordinates();
          var wgs84coordinates = coordinates.map(function(c) {
            return vcs.Projection.mercatorToWgs84(c);
          });

          var geoJSONShape = {
            type: "Feature",
            geometry: {
              type: 'Polygon',
              coordinates: [wgs84coordinates]
            },
            properties: {}
          };

          var shapeString = JSON.stringify(geoJSONShape);

          $(app.customMapOptions.latitudeInputSelector).val(wgs84coordinates[0][1]);
          $(app.customMapOptions.longitudeInputSelector).val(wgs84coordinates[0][0]);
          $(app.customMapOptions.zoomInputSelector).val(10); // TODO: fix this line
          $(app.customMapOptions.shapeInputSelector).val(shapeString);
        }

        session.stop();

        // reactivate feature info by creating new feature info session
        App.VCMap.createFeatureInfoSession(app);
      });
      var destroy = function() {
        featureCreatedDestroy();
        finishedDestroy();
      };
      return destroy;
    },

    drawPredefinedFeatures: function(app, element) {
      var processCoordinates = $(element).data("process-coordinates");
      var process = $(element).data("parent-class");

      processCoordinates.forEach(function(coordinates) {
        App.VCMap.drawPredefinedFeature(app, coordinates, process)
      });
    },

    drawPredefinedFeature: function(app, coordinates, process) {
      var layer = app.layers.getByKey('_demoDrawingLayer') || App.VCMap.createSimpleEditorLayer(app);
      var feature;

      if (App.Map.validCoordinates(coordinates)) { // geometryType === 'Point'
        feature = new ol.Feature({ geometry: new ol.geom.Point([coordinates.long, coordinates.lat])});

        var pinStyle = new vcs.VectorStyleItem({});
        pinStyle.image = new ol.style.Icon({
          color: coordinates.color,
          src: '../dist3/assets/cesium/Assets/Textures/pin.svg',
          scale: 1,
        });
        feature.setStyle(pinStyle.style);

        feature.process = process;
        feature.resource_id = getResourceId(coordinates);
        layer.addFeatures([feature]);

      } else { // geometryType === 'Polygon'
        var polygoneCoordinates = coordinates.geometry.coordinates[0].map(function(c) {
          return [c[0], c[1]];
        });

        feature = new ol.Feature({ geometry: new ol.geom.Polygon([polygoneCoordinates])});
        // var polygonStyle = new vcs.VectorStyleItem({});
        // polygonStyle.fillColor = coordinates.color;
        // polygonStyle.strokeColor = "#000000";
        // polygonStyle.strokeWidth = 2;
        // feature.setStyle(polygonStyle.style);

        feature.process = process;
        feature.resource_id = getResourceId(coordinates);
        layer.addFeatures([feature]);
      }

      function getResourceId(coordinates) {
        var id;

        if (process == "proposals") {
          id = coordinates.proposal_id
        } else if (process == "deficiency-reports") {
          id = coordinates.deficiency_report_id
        } else if (process == "projekts") {
          id = coordinates.projekt_id
        } else {
          id = coordinates.investment_id
        }

        return id
      }
    },

    clearFeatures: function(app) {
      event.preventDefault();
      var layer = app.layers.getByKey('_demoDrawingLayer') || App.VCMap.createSimpleEditorLayer(app);
      layer.removeAllFeatures();
    },

    showFeatureInfo: function(feature) {

      // function to open feature info popup
      var openMarkerPopup = function(feature) {
        var route;

        if ( feature.process == "proposals" ) {
          route = "/proposals/" + feature.resource_id + "/json_data"
        } else if ( feature.process == "deficiency-reports") {
          route = "/deficiency_reports/" + feature.resource_id + "/json_data"
        } else if ( feature.process == "projekts") {
          route = "/projekts/" + feature.resource_id + "/json_data"
        } else {
          route = "/investments/" + feature.resource_id + "/json_data"
        }

        // marker = e.target;
        $.ajax(route, {
          type: "GET",
          dataType: "json",
          success: function(data) {
            ///e.target.bindPopup(getPopupContent(data)).openPopup();
            alert(getPopupContent(data, feature));
          }
        });
      };

      // function to generate marker popup content
      var getPopupContent = function(data, feature) {
        if (feature.process == "proposals" || data.proposal_id) {
          return "<a href='/proposals/" + data.proposal_id + "'>" + data.proposal_title + "</a>";
        } else if ( feature.process == "deficiency-reports" ) {
          return "<a href='/deficiency_reports/" + data.deficiency_report_id + "'>" + data.deficiency_report_title + "</a>";
        } else if ( feature.process == "projekts" ) {
          return "<a href='/projekts/" + data.projekt_id + "'>" + data.projekt_title + "</a>";
        } else {
          return "<a href='/budgets/" + data.budget_id + "/investments/" + data.investment_id + "'>" + data.investment_title + "</a>";
        }
      };

      openMarkerPopup(feature);
    }
  };
}).call(this);

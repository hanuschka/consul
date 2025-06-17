(function() {
  "use strict";
  App.VCMap = {
    initialize: function() {
      document.querySelectorAll("[data-vcmap]").forEach(function(element) {
        App.VCMap.initializeMap(element);
      });
    },

    initializeMap: function(element) {
      // init App and load a config file
      var vcsApp = new window.vcs.VcsApp();
      vcsApp.maps.setTarget(element);
      // App.VCMap.loadModule(vcsApp, 'https://siegburg.virtualcitymap.de/app.config.json');
      App.VCMap.loadModule(vcsApp, 'https://siegburg.virtualcitymap.de/configs/93c036a6-0082-4b8c-a4e5-5e8eeef62f22.json');

      // custom map options
      vcsApp.customMapOptions = {}

      // variables to set map view
      vcsApp.customMapOptions.mapCenterLatitude = $(element).data("map-center-latitude");
      vcsApp.customMapOptions.mapCenterLongitude = $(element).data("map-center-longitude");
      vcsApp.customMapOptions.mapCenterZoom = $(element).data("map-zoom");

      vcsApp.customMapOptions.adminShape = $(element).data("admin-shape");
      vcsApp.customMapOptions.showAdminShape = $(element).data("show-admin-shape");

      vcsApp.customMapOptions.adminEditor = $(element).data("admin-editor");

      // variables that define location and tooltips of process coordinates (both pins and shapes)
      vcsApp.customMapOptions.processCoordinates = $(element).data("process-coordinates");
      vcsApp.customMapOptions.process = $(element).data("parent-class");

      // variables to define map form input selectors
      vcsApp.customMapOptions.latitudeInputSelector = $(element).data("latitude-input-selector");
      vcsApp.customMapOptions.longitudeInputSelector = $(element).data("longitude-input-selector");
      vcsApp.customMapOptions.altitudeInputSelector = $(element).data("altitude-input-selector");
      vcsApp.customMapOptions.zoomInputSelector = $(element).data("zoom-input-selector");
      vcsApp.customMapOptions.shapeInputSelector = $(element).data("shape-input-selector");

      vcsApp.customMapOptions.defaultColor = $(element).data("default-color");
      vcsApp.customMapOptions.editable = $(element).data("editable")

      // create new feature info session to allow feature click interaction
      App.VCMap.createFeatureInfoSession(vcsApp);

      // set cesium base url
      window.CESIUM_BASE_URL = '/vcmap/assets/cesium/';
      // adding helper instance to window
      window.vcsApp = vcsApp;

      // add predefined shapes


      if (vcsApp.customMapOptions.adminEditor && vcsApp.customMapOptions.adminShape ) {
        App.VCMap.drawPredefinedFeature(vcsApp, vcsApp.customMapOptions.adminShape, '_editorLayer');

      } else if (vcsApp.customMapOptions.editable) {
        if (vcsApp.customMapOptions.adminShape && vcsApp.customMapOptions.showAdminShape) {
          App.VCMap.drawPredefinedFeature(vcsApp, vcsApp.customMapOptions.adminShape, '_adminShapeLayer')
        }
        App.VCMap.drawPredefinedFeatures(vcsApp, '_editorLayer');

      } else {
        App.VCMap.drawPredefinedFeature(vcsApp, vcsApp.customMapOptions.adminShape, '_adminShapeLayer');
        App.VCMap.drawPredefinedFeatures(vcsApp, '_processCoordinatesLayer');
      }

      vcsApp.maps.mapActivated.addEventListener(function(map) {
        // set default view
        if ( map.className === 'CesiumMap') {
          App.VCMap.setDefaultView(vcsApp, map);
        }

        // enable editing new points without having user to enable it manually
        if (vcsApp.customMapOptions.editable) {
          App.VCMap.drawFeature(vcsApp, vcs.GeometryType.Point)
        }
      });
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

    createMapLayer: function(app, layerName) {
      var layer = new vcs.VectorLayer({
        name: layerName,
        projection: vcs.wgs84Projection.toJSON(),
        zIndex: vcs.maxZIndex - 1,
        vectorProperties: {
          altitudeMode: 'absolute'
        }
      });

      var fillColor = layerName === '_adminShapeLayer' ? '#ff0000' : app.customMapOptions.defaultColor;

      // layer style
      var style = new vcs.VectorStyleItem({
        fill: {
          color: fillColor
        },
        stroke: {
          color: '#ffffff',
          width: 3,
        },
        image: {
          color: app.customMapOptions.defaultColor,
          src: '/vcmap/assets/cesium/Assets/Textures/pin.svg',
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

    // setActiveMap: function(maps, mapName) {
    //   maps.setActiveMap(mapName);
    // },

    setDefaultView: function(app, map) {
      var mapCenterLat = app.customMapOptions.mapCenterLatitude;
      var mapCenterLong = app.customMapOptions.mapCenterLongitude;

      var zoomMatrix = {
        18: 200,
        17: 400,
        16: 800,
        15: 1400,
        14: 2400,
        13: 4800,
        12: 9600
      };

      var viewpoint = new vcs.Viewpoint({
        "groundPosition": [
          mapCenterLong,
          mapCenterLat,
        ],
        "distance": zoomMatrix[app.customMapOptions.mapCenterZoom] || 9600,
        "pitch": -35,
        "animate": true
      });

      map.gotoViewpoint(viewpoint);
    },

    drawFeature: function(app, geometryType) {
      var layer = app.layers.getByKey('_editorLayer') || App.VCMap.createMapLayer(app, '_editorLayer');
      layer.activate();

      var adminShapeLayer = app.layers.getByKey('_adminShapeLayer');
      var session = vcs.startCreateFeatureSession(app, layer, geometryType);
      var featureCreatedDestroy = session.featureCreated.addEventListener(function(feature) {
        layer.getFeatures().forEach(function(f) {
          console.log(f.getId());
          if (f.getId() !== feature.getId()) {
            layer.removeFeaturesById([f.getId()])
          }
        })

        if ( feature.getGeometry() instanceof ol.geom.Polygon ) {
          feature.set('olcs_altitudeMode', 'clampToGround');
        }
      });

      // to draw only a single feature, stop the session, after creationFinished was fired
      var finishedDestroy = session.creationFinished.addEventListener(function(feature) {
        feature = feature

        if ( !feature ) { return; }

        // convert Mercator coordinates to WGS84
        var geometry = feature.getGeometry();
        if (geometry instanceof ol.geom.Point) {
          var wgs84coordinates = vcs.Projection.mercatorToWgs84(geometry.getCoordinates());

          $(app.customMapOptions.latitudeInputSelector).val(wgs84coordinates[1]);
          $(app.customMapOptions.longitudeInputSelector).val(wgs84coordinates[0]);
          $(app.customMapOptions.altitudeInputSelector).val(wgs84coordinates[2]);
          $(app.customMapOptions.zoomInputSelector).val(app.customMapOptions.mapCenterZoom);
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
          $(app.customMapOptions.zoomInputSelector).val(app.customMapOptions.mapCenterZoom);
          $(app.customMapOptions.shapeInputSelector).val(shapeString);
        }
      });
      var destroy = function() {
        featureCreatedDestroy();
        finishedDestroy();
      };
      return destroy;
    },

    drawPredefinedFeatures: function(app, layerName) {
      app.customMapOptions.processCoordinates.forEach(function(coordinates) {
        App.VCMap.drawPredefinedFeature(app, coordinates, layerName)
      });
    },

    drawPredefinedFeature: function(app, coordinates, layerName) {
      var layer = app.layers.getByKey(layerName) || App.VCMap.createMapLayer(app, layerName);
      var feature;

      if (App.Map.validCoordinates(coordinates)) { // geometryType === 'Point'
        feature = new ol.Feature({ geometry: new ol.geom.Point([coordinates.long, coordinates.lat, coordinates.alt])});

        var pinStyle = new vcs.VectorStyleItem({});
        pinStyle.image = new ol.style.Icon({
          color: coordinates.color,
          src: '/vcmap/assets/cesium/Assets/Textures/pin.svg',
          scale: 1,
        });
        feature.setStyle(pinStyle.style);

        feature.process = app.customMapOptions.process;
        feature.resource_id = getResourceId(coordinates);
        layer.addFeatures([feature]);

      } else { // geometryType === 'Polygon'
        var polygoneCoordinates = coordinates.geometry.coordinates[0].map(function(c) {
          return [c[0], c[1], c[2]];
        });

        feature = new ol.Feature({ geometry: new ol.geom.Polygon([polygoneCoordinates])});

        var polygonStyle = new vcs.VectorStyleItem({});
        polygonStyle.fillColor = coordinates.color;
        polygonStyle.stroke = new ol.style.Stroke({
          color: "#000",
          width: 1
        });
        feature.setStyle(polygonStyle.style);

        feature.set('olcs_altitudeMode', 'clampToGround');

        feature.process = app.customMapOptions.process;
        feature.resource_id = getResourceId(coordinates);
        layer.addFeatures([feature]);
      }

      function getResourceId(coordinates) {
        var id;

        if (app.customMapOptions.process == "proposals") {
          id = coordinates.proposal_id
        } else if (app.customMapOptions.process == "deficiency-reports") {
          id = coordinates.deficiency_report_id
        } else if (app.customMapOptions.process == "projekts") {
          id = coordinates.projekt_id
        } else {
          id = coordinates.investment_id
        }

        return id
      }
    },

    clearFeatures: function(app) {
      var layer = app.layers.getByKey('_editorLayer') || App.VCMap.createMapLayer(app, '_editorLayer');
      layer.removeFeaturesById(['_shape']);
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
            $("#vc-popup").html(getPopupContent(data, feature));
            $("#vc-popup").show();
          }
        });
      };

      // function to generate marker popup content
      var getPopupContent = function(data, feature) {
        if (feature.process == "proposals" || data.proposal_id) {
          return proposalPopupContent(data)
        } else if ( feature.process == "deficiency-reports" ) {
          return "<a href='/deficiency_reports/" + data.deficiency_report_id + "'>" + data.deficiency_report_title + "</a>";
        } else if ( feature.process == "projekts" ) {
          return "<a href='/projekts/" + data.projekt_id + "'>" + data.projekt_title + "</a>";
        } else {
          return "<a href='/budgets/" + data.budget_id + "/investments/" + data.investment_id + "'>" + data.investment_title + "</a>";
        }

        function proposalPopupContent(data) {
          var popupHtml = "";
          popupHtml += "<h6 style='max-width:140px;margin-top:10px;'><a href='/proposals/" + data.proposal_id + "'>" + data.proposal_title + "</a></h6>"; //title

          if (data.image_url) {
            popupHtml += "<img src='" + data.image_url + "' style='margin-bottom:10px;'>"; //image
          }

          if (data.labels.length || Object.keys(data.sentiment).length) {
            popupHtml += "<div class='resource-taggings'>";

            if (data.labels.length) {
              var labels = "<div class='projekt-labels' style='max-width:120px;'>";
              data.labels.forEach(function(label) {
                labels += "<span class='projekt-label selected'>"
                labels += "<i class='fas fa-" + label.icon + "' style='margin-right:4px;'></i>"
                labels += label.name
                labels += "</span>";
              });
              labels += "</div>";
              popupHtml += labels;
            }

            if (Object.keys(data.sentiment).length) {
              var sentiments = "<div class='sentiments' style='max-width:120px;'>";
              sentiments += "<span class='sentiment' style='background-color:#454B1B;color:#ffffff'>" + data.sentiment.name + "</span>";
              sentiments += "</div>";
              popupHtml += sentiments;
            }

            popupHtml += "</div>";
          }

          popupHtml += "<a class='popup-close-button' onclick='$(\"#vc-popup\").hide();' href='#close' style='outline: none;'>×</a>"

          return popupHtml;
        }
      };

      openMarkerPopup(feature);
    }
  };
}).call(this);

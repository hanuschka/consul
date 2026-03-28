(function() {
  "use strict";

  class VirtualcityMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();
      // this.bindEventListeners();

      this.createMap();
      // this.setupLayers();
      // this.setupPlugins();
      // this.setupEventListenersForUpdatingFormInputs();
      // this.setupEventListenersForUpdatingMapCenter();
    }

    initializeProperties() {
      const $element = $(this.element);

      // Map configuration
      this.mapCenterLatitude = $element.data("map-center-latitude");
      this.mapCenterLongitude = $element.data("map-center-longitude");
      this.mapCenterLatLng = new L.LatLng(this.mapCenterLatitude, this.mapCenterLongitude);
      this.mapCenterAltitude = $element.data("map-center-altitude");
      this.zoom = $element.data("map-zoom");
      this.placement = $element.data("placement");

      /// // Layer configuration
      /// this.layersData = $element.data('layers-data');
      /// this.baseLayers = {};
      /// this.overlayLayers = {};
      this.adminFeatures = $element.data("admin-features");

      // Features configuration
      this.features = $element.data("features");
      this.process = $element.data("process");

      // Editing configuration
      this.editable = $element.data("editable");
      this.adminEditor = $element.data("admin-editor");
      this.editingProjektMap = $element.data("editing-projekt-map");
      this.enableShapes = $element.data("enable-shapes");
      this.editableLayers = [];
      this.editableLayersLimit = $element.data("map-features-limit")
      /// this.centerMarker = null;
      this.defaultFeatureColor = this.adminEditor ? "#ff0000" : App.Utils.getBrandColor();
      /// this.featureColor = null;
      /// this.featureIconName = null;
      /// this.featureCategoryName = null;

      // Form inputs
      this.latitudeInput = document.querySelector('[data-latitude-input-for="' + this.element.id + '"]');
      this.longitudeInput = document.querySelector('[data-longitude-input-for="' + this.element.id + '"]');
      this.altitudeInput = document.querySelector('[data-longitude-input-for="' + this.element.id + '"]');
      this.zoomInput = document.querySelector('[data-zoom-input-for="' + this.element.id + '"]');
      this.featuresInput = document.querySelector('[data-features-input-for="' + this.element.id + '"]');
    }

    bindEventListeners() {
      /// this.openMarkerPopup = this.openMarkerPopup.bind(this);
    }

    createMap() {
      const instance = this;

      const script = document.createElement('script');
      script.src = '/vcmap/vcmap-core.js';
      script.type = 'module';
      document.head.appendChild(script);

      script.onload = function() {
        function addZoomControls() {
          const zoomControlContainer = document.createElement('div');
          zoomControlContainer.className = 'controls zoom-controls';
          instance.element.appendChild(zoomControlContainer);

          const zoomInButton = document.createElement('button');
          zoomInButton.addEventListener('click', function(event) { zoom(true); });
          zoomInButton.innerHTML = '+';
          zoomControlContainer.appendChild(zoomInButton);

          const zoomOutButton = document.createElement('button');
          zoomOutButton.addEventListener('click', function(event) { zoom(false); });
          zoomOutButton.innerHTML = '−';
          zoomControlContainer.appendChild(zoomOutButton);
        }

        function zoom(zoomIn) {
          event.preventDefault();

          instance.map.getViewpoint().then(function(viewpoint) {
            if (zoomIn) {
              viewpoint.distance /= 2;
            } else {
              viewpoint.distance *= 2;
            }

            viewpoint.animate = true;
            viewpoint.duration = 0.5;
            viewpoint.cameraPosition = null;

            instance.map.gotoViewpoint(viewpoint);
          });
        }

        function loadModule(app, url) {
          fetch(url)
            .then(function(response) {
              if (!response.ok) {
                throw new Error('Network response was not ok ' + response.statusText);
              }
              return response.json();
            })
            .then(function(config) {
              const module = new window.vcs.VcsModule(config);
              app.addModule(module, function(err) {
                if (err) {
                  console.log('Error adding module:', err);
                } else {
                  console.log('Module added:', url);
                }
              });
            })
            .catch(function(error) {
              console.log('Error loading module:', error);
            });
        }

        function setDefaultView(map) {
          const zoomMatrix = {
            18: 200,
            17: 400,
            16: 800,
            15: 1400,
            14: 2400,
            13: 4800,
            12: 9600
          };

          const viewpoint = new vcs.Viewpoint({
            "groundPosition": [
              instance.mapCenterLongitude,
              instance.mapCenterLatitude
            ],
            "distance": zoomMatrix[instance.zoom] || 9600,
            "pitch": -35,
            "animate": true
          });

          map.gotoViewpoint(viewpoint);
        }

        instance.app = new window.vcs.VcsApp();
        instance.app.maps.setTarget(instance.element);
        loadModule(instance.app, '/vcmap/kempten3.config.json')

        window.CESIUM_BASE_URL = '/vcmap/assets/cesium/';
        window.vcsApp = instance.app;

        instance.app.maps.mapActivated.addEventListener(function(map) {
          if ( map.className === 'CesiumMap') {
            instance.map = map;
            setDefaultView(map);
            addZoomControls();
            instance.toggleControlVisibility();
            instance.setupExpandControl();
            instance.setupEditingControls();
            instance.renderFeatures();
            instance.addAdminFeaturesAsLayer();
            instance.createFeatureInfoSession();
          }
        });
      }

      if (this.editableLayersLimit && this.editableLayersLimit > 1) {
        this.addHintAboutEditableLayersLimit();
      }
    }

    setupEventListenersForNewFeatures() {
    }

    setupExpandControl() {
      const instance = this;

      const expandControlContainer = document.createElement('div');
      expandControlContainer.className = 'controls expand-control';
      instance.element.appendChild(expandControlContainer);

      const expandButton = document.createElement('button');
      expandButton.type = 'button';
      expandButton.innerHTML = '<i class="fas fa-expand"></i>';
      expandButton.title = 'Vollbild-Modus';
      expandControlContainer.appendChild(expandButton);

      expandButton.addEventListener('click', function(e) {
        e.preventDefault();

        if (instance.element.classList.contains('expanded')) {
          instance.element.classList.remove('expanded');
          expandButton.innerHTML = '<i class="fas fa-expand"></i>';
          instance.toggleControlVisibility();
        } else {
          instance.element.classList.add('expanded');
          expandButton.innerHTML = '<i class="fas fa-compress"></i>';
          instance.toggleControlVisibility();
        }
      });
    }

    // setupLayers() {
    // }

    // createLayer(item) {
    // }

    addAdminFeaturesAsLayer() {
      const instance = this;

      if (Array.isArray(instance.adminFeatures)) {
        instance.adminFeatures.forEach(function(featuresCollection) {
          featuresCollection.features.forEach(function(feature) {
            instance.drawPredefinedFeature(feature, '_adminFeaturesLayer', '#008000');
          });
        });
      } else if (instance.adminFeatures.type === 'FeatureCollection') {
        instance.adminFeatures.features.forEach(function(feature) {
          instance.drawPredefinedFeature(feature, '_adminFeaturesLayer', '#008000');
        });
      } else if (instance.adminFeatures.type === 'Feature') {
        instance.drawPredefinedFeature(instance.adminFeatures, '_adminFeaturesLayer', '#008000');
      }
    }

    addHintAboutEditableLayersLimit() {
      const hintControl = document.createElement('div');
      hintControl.className = 'controls feature-limit-hint-control';
      hintControl.innerHTML = 'Sie dürfen insgesamt ' + this.editableLayersLimit + ' Pins setzen.'

      this.element.appendChild(hintControl);
    }

    renderAdminFeaturesNote() {
    }

    setupPlugins() {
    }

    renderFeatures() {
      if (this.features && Object.keys(this.features).length > 0) {
        const instance = this;
        const layerName = instance.editable ? '_editorLayer' : '_predefinedFeaturesLayer';

        if (Array.isArray(instance.features)) {
          instance.features.forEach(function(element) {
            if (element.type === 'FeatureCollection') {
              element.features.forEach(function(feature) {
                instance.drawPredefinedFeature(feature, layerName, instance.defaultFeatureColor);
              });
            } else if (element.type === 'Feature') {
              instance.drawPredefinedFeature(element, layerName, instance.defaultFeatureColor);
            }
          });
        } else if (instance.features.type === 'FeatureCollection') {
          instance.features.features.forEach(function(feature) {
            instance.drawPredefinedFeature(feature, layerName, instance.defaultFeatureColor);
          });
        } else if (instance.features.type === 'Feature') {
          instance.drawPredefinedFeature(instance.features, layerName, instance.defaultFeatureColor);
        }
      }
    }

    drawPredefinedFeature(feature, layerName, color) {
      const layer = this.app.layers.getByKey(layerName) || this.createMapLayer(layerName);
      let vcfeature;

      if (feature.geometry.type === 'Point') {
        vcfeature = new ol.Feature({ geometry: new ol.geom.Point([
          feature.geometry.coordinates[0],
          feature.geometry.coordinates[1],
          feature.geometry.coordinates[2]
        ])});

        const pinStyle = new vcs.VectorStyleItem({});
        pinStyle.image = new ol.style.Icon({
          src: App.Utils.getVirtualcityMarkerHTML(color)
        });

        vcfeature.setStyle(pinStyle.style);
        vcfeature.set('olcs_altitudeMode', 'absolute');

        vcfeature.data = {
          resource_type: feature.properties.resource_type,
          resource_id: feature.properties.id,
          id: feature.properties.id
        }

        layer.addFeatures([vcfeature]);

      } else if (feature.geometry.type === 'Polygon') {
        const vcfeature_coordinates = feature.geometry.coordinates[0].map(function(c) {
          return [c[0], c[1], c[2]];
        });
        vcfeature = new ol.Feature({ geometry: new ol.geom.Polygon([vcfeature_coordinates])});

        const polygonStyle = new vcs.VectorStyleItem({});
        polygonStyle.fillColor = App.Utils.hexToRgba(color, 0.3);
        polygonStyle.stroke = new ol.style.Stroke({
          color: "#ffffff",
          width: 3
        });

        vcfeature.setStyle(polygonStyle.style);
        vcfeature.set('olcs_altitudeMode', 'relativeToGround');

        vcfeature.data = {
          resource_type: feature.properties.resource_type,
          resource_id: feature.properties.id,
          id: feature.properties.id
        }


        layer.addFeatures([vcfeature]);
      }
    }

    createFeatureInfoSession() {
      const instance = this;

      function CustomFeatureInfoInteraction(instance) {
        window.vcs.AbstractInteraction.call(
          this,
          window.vcs.EventType.CLICK,
          window.vcs.ModificationKeyType.NONE
        );

        this.instance = instance;
        this.layerName = '_popupLayer';
        window.vcs.AbstractInteraction.prototype.setActive.call(this);
      }

      CustomFeatureInfoInteraction.prototype = Object.create(window.vcs.AbstractInteraction.prototype);
      CustomFeatureInfoInteraction.prototype.constructor = CustomFeatureInfoInteraction;

      CustomFeatureInfoInteraction.prototype.pipe = function(event) {
        const feature = event.feature
        const featureLayerName = feature[window.vcs.vcsLayerName]
        const editable = this.instance.editable

        if (feature && !editable && featureLayerName == '_predefinedFeaturesLayer') {
          this.instance.openMarkerPopup(feature);
        }
        return event;
      };

      const eventHandler = this.app.maps.eventHandler;
      let stop;

      const interaction = new CustomFeatureInfoInteraction(instance);

      const listener = eventHandler.addExclusiveInteraction(interaction, function() {
        if (stop) stop();
      });

      const currentType = eventHandler.featureInteraction.active;
      eventHandler.featureInteraction.setActive(window.vcs.EventType.CLICK);

      const stopped = new window.vcs.VcsEvent();

      stop = function() {
        listener();
        interaction.destroy();
        eventHandler.featureInteraction.setActive(currentType);
        stopped.raiseEvent();
        stopped.destroy();
      };

      return { stopped, stop };
    }

    openMarkerPopup(feature) {
      const instance = this;

      const existing = document.getElementById('vc-popup');
      if (existing) existing.remove();

      const popup = document.createElement('div');
      popup.id = 'vc-popup';
      popup.className = 'leaflet-popup-content-wrapper';

      const popupContent = document.createElement('div');
      popupContent.id = "vc-popup-content"
      popupContent.className = 'leaflet-popup-content';

      const closeButton = document.createElement('a');
      closeButton.className = 'popup-close-button';
      closeButton.href = '#close';
      closeButton.style.outline = 'none';
      closeButton.innerHTML = '×';
      closeButton.onclick = function(e) { e.preventDefault(); $("#vc-popup").remove(); };

      popup.appendChild(closeButton);
      popup.appendChild(popupContent);

      const resourceType = feature.data.resource_type;
      const resourceId = feature.data.id;
      const popupDataUrl = App.MapPopup.getPopupDataUrl(resourceType, feature.data);

      if (!popupDataUrl) { return };

      $.ajax(popupDataUrl, {
        type: "GET",
        dataType: "json",
        success: function(data) {
          popupContent.innerHTML = App.MapPopup.generatePopupContent(data, resourceType);
          instance.element.appendChild(popup);
        }
      });
    }

    createMapLayer(layerName) {
      const layer = new vcs.VectorLayer({
        name: layerName,
        projection: vcs.wgs84Projection.toJSON(),
        zIndex: vcs.maxZIndex - 1,
        vectorProperties: {
          altitudeMode: 'relativeToGround'
        }
      });

      // layer will not be serialized
      vcs.markVolatile(layer);
    
      // activate and add layer
      layer.activate();
      this.app.layers.add(layer);

      return layer;
    }

    setupEditingControls() {
      if (!this.editable)  return;

      const instance = this;

      function drawFeature(geometryType) {
        const layer = instance.app.layers.getByKey('_editorLayer') || instance.createMapLayer('_editorLayer');
        layer.activate();

        const session = vcs.startCreateFeatureSession(instance.app, layer, geometryType);

        function convertToGeoJSONFeature(feature) {
          const geometry = feature.getGeometry();
          let geoJSONFeature = {
            type: "Feature",
            geometry: {},
            properties: {}
          };

          if (geometry instanceof ol.geom.Point) {
            const wgs84coordinates = vcs.Projection.mercatorToWgs84(geometry.getCoordinates());

            geoJSONFeature.geometry.type = 'Point';
            geoJSONFeature.geometry.coordinates = [wgs84coordinates[0], wgs84coordinates[1], wgs84coordinates[2]];

          } else if (geometry instanceof ol.geom.Polygon) {
            const wgs84coordinates = geometry.getLinearRing(0).getCoordinates().map(function(c) {
              return vcs.Projection.mercatorToWgs84(c);
            });

            geoJSONFeature.geometry.type = 'Polygon';
            geoJSONFeature.geometry.coordinates = [wgs84coordinates];
          }
          return geoJSONFeature;
        }

        session.featureCreated.addEventListener(function(feature) {
          if (!instance.adminEditor && layer.getFeatures().length > instance.editableLayersLimit) {
            layer.removeFeaturesById([layer.getFeatures()[0].getId()]);
          }

          if ( feature.getGeometry() instanceof ol.geom.Polygon ) {
            feature.set('olcs_altitudeMode', 'relativeToGround');
            const polygonStyle = new vcs.VectorStyleItem({});
            polygonStyle.fillColor = App.Utils.hexToRgba(instance.defaultFeatureColor, 0.3);
            polygonStyle.stroke = new ol.style.Stroke({
              color: "#fff",
              width: 2 
            });
            feature.setStyle(polygonStyle.style);
          } else if ( feature.getGeometry() instanceof ol.geom.Point ) {
            feature.set('olcs_altitudeMode', 'relativeToGround');
            const editorPinStyle = new vcs.VectorStyleItem({});
            editorPinStyle.image = new ol.style.Icon({
              src: App.Utils.getVirtualcityMarkerHTML(instance.defaultFeatureColor)
            });
            feature.setStyle(editorPinStyle.style);
          }
        });

        session.creationFinished.addEventListener(function(feature) {
          if ( !feature ) { return; }

          const geoJSON = {
            type: "FeatureCollection",
            features: layer.getFeatures().map(function(f) {
              return convertToGeoJSONFeature(f);
            })
          }

          instance.featuresInput.value = JSON.stringify(geoJSON);
        });
      }

      const editingControlContainer = document.createElement('div');
      editingControlContainer.className = 'controls editing-controls';
      instance.element.appendChild(editingControlContainer);

      const drawPointControl = document.createElement('button');
      drawPointControl.type = 'button';
      drawPointControl.innerHTML = '<i class="fas fa-map-marker-alt"></i>';
      drawPointControl.title = 'Pin setzen';
      editingControlContainer.appendChild(drawPointControl);

      drawPointControl.addEventListener('click', function(e) {
        e.preventDefault();
        drawFeature(vcs.GeometryType.Point)
      });

      const drawPolygonControl = document.createElement('button');
      drawPolygonControl.type = 'button';
      drawPolygonControl.innerHTML = '<i class="fas fa-draw-polygon"></i>';
      drawPolygonControl.title = 'Fläche zeichnen';
      editingControlContainer.appendChild(drawPolygonControl);

      drawPolygonControl.addEventListener('click', function(e) {
        e.preventDefault();
        drawFeature(vcs.GeometryType.Polygon)
      });

      const clearControl = document.createElement('button');
      clearControl.type = 'button';
      clearControl.innerHTML = '<i class="fas fa-trash-alt"></i>';
      clearControl.title = 'Alle Objekte entfernen';
      editingControlContainer.appendChild(clearControl);

      clearControl.addEventListener('click', function(e) {
        e.preventDefault();
        const layer = instance.app.layers.getByKey('_editorLayer') || instance.createMapLayer('_editorLayer');
        instance.app.layers.remove(layer)
        instance.featuresInput.value = JSON.stringify({ type: "FeatureCollection", features: [] });
      });
    }

    placeCenterMarker(centerLatLng, instance) {
      /// if (instance.centerMarker) {
      ///   instance.map.removeLayer(instance.centerMarker);
      /// }

      /// const centerMarker = L.marker(centerLatLng, {
      ///   draggable: true,
      ///   icon: App.Utils.getVirtualcityMarkerHTML()
      /// })

      /// instance.centerMarker = centerMarker;
      /// instance.map.addLayer(centerMarker);
      /// instance.latitudeInput.value = centerMarker.getLatLng().lat.toFixed(6);
      /// instance.longitudeInput.value = centerMarker.getLatLng().lng.toFixed(6);
    }

    setupEventListenersForEditableFeature(map, layer) {
      /// layer.on('click', function() {
      ///   if (!map.pm.globalDrawModeEnabled() && !map.pm.globalDragModeEnabled() && !layer.pm.enabled()) {
      ///     layer.pm.enable({ allowSelfIntersection: false });
      ///   }
      /// });

      /// map.on('click', function(e) {
      ///   const isMarker = layer instanceof L.Marker;

      ///   if (!isMarker && layer.pm.enabled() && !layer.getBounds().contains(e.latlng)) {
      ///     layer.pm.disable();
      ///   }
      /// });

      /// layer.on("pm:drawstart", function() { layer.pm.disable() });
      /// layer.on("pm:dragenable", function() { layer.pm.disable() });
    }

    setupEventListenersForUpdatingFormInputs() {
      /// if (!this.editable) return;

      /// const self = this;

      /// this.map.on('move', function() {
      ///   if (!self.editingProjektMap) {
      ///     self.latitudeInput.value = self.map.getCenter().lat.toFixed(6);
      ///     self.longitudeInput.value = self.map.getCenter().lng.toFixed(6);
      ///     self.zoomInput.value = self.map.getZoom();
      ///   }
      /// });

      /// this.map.on('zoomend', function() {
      ///   self.zoomInput.value = self.map.getZoom();
      /// });

      /// this.map.on('pm:create', function(e) {
      ///   if (!self.adminEditor && self.editableLayers.length >= self.editableLayersLimit) {
      ///     self.map.removeLayer(self.editableLayers.pop());
      ///   }

      ///   self.editableLayers.push(e.layer);

      ///   e.layer.on('pm:edit', function(e) {
      ///     self.updateFeaturesInput(self.featuresInput, self.editableLayers);
      ///   });

      ///   self.updateFeaturesInput(self.featuresInput, self.editableLayers);
      ///   self.zoomInput.value = self.map.getZoom();
      /// });

      /// this.map.on('pm:dragend', function(e) {
      ///   if (!self.editingProjektMap) {
      ///     self.latitudeInput.value = self.map.getCenter().lat.toFixed(6);
      ///     self.longitudeInput.value = self.map.getCenter().lng.toFixed(6);
      ///     self.zoomInput.value = self.map.getZoom();
      ///   }
      /// });
    }

    updateFeaturesInput(featuresInput, editableLayers) {
      /// L.Layer.include({
      ///   toGeoJSONWithOptions: function() {
      ///     const layer = this;
      ///     const allowedOptions = ['feature_color', 'feature_icon_name', 'feature_category_name'];
      ///     const geojson = this.toGeoJSON();
      ///     geojson.properties = geojson.properties || {};

      ///     allowedOptions.forEach( function(option) {
      ///       if ( option in layer.options ) {
      ///         geojson.properties[option] = layer.options[option];
      ///       }
      ///     })
      ///     return geojson;
      ///   }
      /// })

      /// const featuresData = editableLayers.map(function(layer) {
      ///   if ( layer.options.shape == 'Circle' ) {
      ///     return L.PM.Utils.circleToPolygon(layer, 60).toGeoJSONWithOptions();
      ///   } else {
      ///     return layer.toGeoJSONWithOptions();
      ///   }
      /// })

      /// var featureCollection = {
      ///   type: 'FeatureCollection',
      ///   features: featuresData
      /// };

      /// featuresInput.value = JSON.stringify(featureCollection);
    }

    toggleControlVisibility() {
      // const layerControl = this.element.querySelector('.leaflet-control-layers');
      // const locateControl = this.element.querySelector('.leaflet-control-locate');
      // const geoSearchControl = this.element.querySelector('.leaflet-control-container > .leaflet-control-geosearch.leaflet-geosearch-bar');

      // if ( this.element.offsetWidth < 700 ) {
      //   [layerControl, locateControl, geoSearchControl].forEach(control => {
      //     if (control) control.style.display = 'none';
      //   });
      // } else {
      //   [layerControl, locateControl, geoSearchControl].forEach(control => {
      //     if (control) control.style.display = '';
      //   });
      // }
    }

    setupEventListenersForUpdatingMapCenter() {
      /// if (!this.editable) return;

      /// const selectElement = document.querySelector('.js-update-map-center');
      /// if ( !selectElement ) return;

      /// selectElement.addEventListener('change', (event) => {
      ///   const selectedOption = event.target.selectedOptions[0];
      ///   const latitude = selectedOption.dataset.latitude || event.target.dataset.defaultLatitude || this.mapCenterLatitude;
      ///   const longitude = selectedOption.dataset.longitude || event.target.dataset.defaultLongitude || this.mapCenterLongitude;

      ///   if (latitude && longitude) {
      ///     const newCenter = new L.LatLng(latitude, longitude);
      ///     this.map.setView(newCenter, this.map.getZoom());
      ///   }
      /// });
    }
  }

  window.App.VirtualcityMapController = VirtualcityMapController;
}).call(this);

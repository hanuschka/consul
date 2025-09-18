(function() {
  "use strict";

  class LeafletMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();
      this.bindEventListeners();

      this.createMap();
      this.setupExpandControl();
      this.setupLayers();
      this.setupPlugins();
      this.renderFeatures();
      this.setupEditingControls();
      this.setupEventListenersForUpdatingFormInputs();
      this.toggleControlVisibility();
      this.setupEventListenersForUpdatingMapCenter();
    }

    initializeProperties() {
      const $element = $(this.element);

      // Map configuration
      this.mapCenterLatitude = $element.data("map-center-latitude");
      this.mapCenterLongitude = $element.data("map-center-longitude");
      this.mapCenterLatLng = new L.LatLng(this.mapCenterLatitude, this.mapCenterLongitude);
      this.zoom = $element.data("map-zoom");
      this.placement = $element.data("placement");

      // Layer configuration
      this.layersData = $element.data('layers-data');
      this.baseLayers = {};
      this.overlayLayers = {};
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
      this.centerMarker = null;
      this.defaultFeatureColor = this.adminEditor ? "#ff0000" : App.Utils.getBrandColor();
      this.featureColor = null;
      this.featureIconName = null;
      this.featureCategoryName = null;

      // Form inputs
      this.latitudeInput = document.querySelector('[data-latitude-input-for="' + this.element.id + '"]');
      this.longitudeInput = document.querySelector('[data-longitude-input-for="' + this.element.id + '"]');
      this.zoomInput = document.querySelector('[data-zoom-input-for="' + this.element.id + '"]');
      this.featuresInput = document.querySelector('[data-features-input-for="' + this.element.id + '"]');
    }

    bindEventListeners() {
      this.openMarkerPopup = this.openMarkerPopup.bind(this);
    }

    createMap() {
      this.map = L.map(this.element.id, {
        gestureHandling: true,
        maxZoom: 18,
        zoomControl: false
      }).setView(this.mapCenterLatLng, this.zoom);

      const zoomControl = L.control.zoom({
        zoomInTitle: 'Hineinzoomen',
        zoomOutTitle: 'Herauszoomen'
      });

      this.map.addControl(zoomControl);

      this.map.pm.setGlobalOptions({
        markerStyle: {
          icon: App.Utils.getLeafletMarkerHTML(this.defaultFeatureColor),
        },
        pathOptions: {
          weight: 2,
          color: this.defaultFeatureColor,
          opacity: 1,
          fillColor: this.defaultFeatureColor,
          fillOpacity: 0.2
        },
        templineStyle: { color: this.defaultFeatureColor, dashArray: '5, 10' },
        hintlineStyle: { color: this.defaultFeatureColor, dashArray: '5, 10' }
      });

      if (this.editableLayersLimit && this.editableLayersLimit > 1) {
        this.addHintAboutEditableLayersLimit();
      }
    }

    setupEventListenersForNewFeatures() {
      const instance = this;

      instance.map.on('pm:create', function(e) {
        if (e.shape === 'Circle') {
          e.layer.options.shape = 'Circle';
        }

        e.layer.options.feature_color = instance.featureColor;
        e.layer.options.feature_icon_name = instance.featureIconName;
        e.layer.options.feature_category_name = instance.featureCategoryName;

        instance.setupEventListenersForEditableFeature(instance.map, e.layer);
      })
    }

    setupExpandControl() {
      const instance = this;

      L.Control.Expand = L.Control.extend({
        onAdd: function(map) {
          let container = document.createElement('div');
          container.className = 'control-container';

          let button = document.createElement('button');
          button.type = 'button';
          button.className = 'control-button';
          button.innerHTML = '<i class="fas fa-expand"></i>';
          button.title = 'Vollbild-Modus';

          container.appendChild(button);

          L.DomEvent.disableClickPropagation(container);

          container.addEventListener('click', (e) => {
            L.DomEvent.stopPropagation(e);

            if (instance.element.classList.contains('expanded')) {
              instance.element.classList.remove('expanded');
              button.innerHTML = '<i class="fas fa-expand"></i>';
              map.invalidateSize();
              instance.toggleControlVisibility();
            } else {
              instance.element.classList.add('expanded');
              button.innerHTML = '<i class="fas fa-compress"></i>';
              map.invalidateSize();
              instance.toggleControlVisibility();
            }
          });

          return container;
        },

        onRemove() {
          container.remove();
        }
      })

      const expandControl = new L.Control.Expand({ position: 'topright' })
      this.map.addControl(expandControl);
    }

    setupLayers() {
      if (this.adminFeatures && Object.keys(this.adminFeatures).length > 0) {
        this.addAdminFeaturesAsLayer();
      };

      // Create layers
      if (typeof this.layersData !== "undefined") {
        this.layersData.forEach((item) => this.createLayer(item));
      }

      // Ensure at least one base layer existance and add it to the map
      this.ensureBaseLayerExistence();
      this.baseLayers[Object.keys(this.baseLayers)[0]].addTo(this.map);

      // Add to map overlay layers that should be visible by default
      for (let key of Object.keys(this.overlayLayers)) {
        if (this.overlayLayers[key].options.show_by_default === true) {
          this.overlayLayers[key].addTo(this.map);
        }
      }

      // Add layer control if needed
      this.addLayerControl();
    }

    createLayer(item) {
      let layer;

      if (item.protocol === 'wms') {
        layer = L.tileLayer.wms(item.provider, {
          attribution: item.attribution,
          layers: item.layer_names,
          format: (item.transparent ? 'image/png' : 'image/jpeg'),
          transparent: (item.transparent),
          show_by_default: (item.show_by_default),
          opacity: (item.opacity ? item.opacity : 1),
        });
      } else {
        layer = L.tileLayer(item.provider, {
          attribution: item.attribution
        });
      }

      if (item.base) {
        this.baseLayers[item.name] = layer;
      } else {
        this.overlayLayers[item.name] = layer;
      }
    }

    ensureBaseLayerExistence() {
      if (Object.keys(this.baseLayers).length === 0) {
        const defaultLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
        });
        this.baseLayers['defaultLayer'] = defaultLayer;
      }
    }

    addLayerControl() {
      let layerControl = null;

      if (Object.keys(this.baseLayers).length > 1 && Object.keys(this.overlayLayers).length > 0) {
        layerControl = L.control.layers(this.baseLayers, this.overlayLayers).addTo(this.map);
      } else if (Object.keys(this.overlayLayers).length > 0) {
        layerControl = L.control.layers({}, this.overlayLayers).addTo(this.map);
      } else if (this.showAdminShape && !this.adminEditor) {
        layerControl = L.control.layers({}, {}).addTo(this.map);
      }
    }

    addAdminFeaturesAsLayer() {
      const adminFeaturesLayer = L.geoJSON(this.adminFeatures, {
        pointToLayer: function(feature, latlng) {
          return L.marker(latlng, {
            icon: App.Utils.getLeafletMarkerHTML('#ff0000')
          });
        },
        style: {
          color: '#ff0000',
          weight: 2,
          fillOpacity: 0.2
        },
        onEachFeature: (feature, layer) => {
          layer.bindPopup('<div class="map-popup-status-message">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>');
          layer.pm.disable();
          layer.pm.setOptions({
            draggable: false,
            editable: false
          });
        }
      }).addTo(this.map);
      this.overlayLayers['Verwaltungseinträge'] = adminFeaturesLayer;
      this.renderAdminFeaturesNote();
    }

    addHintAboutEditableLayersLimit() {
      const hintText = 'Sie dürfen insgesamt ' + this.editableLayersLimit + ' Pins setzen.'
      const hintControl = L.control({
        position: 'bottomleft'
      })

      hintControl.onAdd = () => {
        const container = L.DomUtil.create('div', 'feature-limit-hint');
        container.innerHTML = hintText;
        container.className += ' leaflet-control-attribution';
        container.style.color = '#ff0000';
        return container;
      };

      hintControl.addTo(this.map);
    }

    renderAdminFeaturesNote() {
      const adminShapeExplainerText = 'Alle markierten Flächen und Pins in rot sind vom System vorgegeben';
      const adminShapeExplainer = L.control({
        position: 'bottomleft'
      });

      adminShapeExplainer.onAdd = () => {
        const container = L.DomUtil.create('div', 'my-attribution');
        container.innerHTML = adminShapeExplainerText;
        container.className += ' leaflet-control-attribution';
        container.style.color = '#ff0000';
        return container;
      };

      adminShapeExplainer.addTo(this.map);
    }

    setupPlugins() {
      L.control.locate({
        icon: 'fa fa-map-marker',
        strings: {
          title: 'Meine Position anzeigen'
        }
      }).addTo(this.map);

      const searchControl = new GeoSearch.GeoSearchControl({
        provider: new GeoSearch.OpenStreetMapProvider(),
        style: 'bar',
        showMarker: false,
        searchLabel: 'Nach Adresse suchen',
        notFoundMessage: 'Entschuldigung! Die Adresse wurde nicht gefunden.',
        clearSearchLabel: 'Suche zurücksetzen'
      });
      this.map.addControl(searchControl);

      this.clusterGroup = L.markerClusterGroup({ removeOutsideVisibleBounds: false });

      // Leaflet.Deflate plugin
      this.deflateFeatures = L.deflate({
        minSize: 30,
        markerLayer: this.clusterGroup,
        markerOptions: (shape) => {
          return {
            icon: App.Utils.getLeafletMarkerHTML(shape.feature.properties.color || this.defaultFeatureColor, shape.feature.properties.feature_icon_name ),
          }
        }

      });

      this.deflateFeatures.addTo(this.map);
    }

    renderFeatures() {
      if (this.features && Object.keys(this.features).length > 0) {
        const self = this;

        L.geoJSON(this.features, {
          pointToLayer: function(feature, latlng) {
            return L.marker(latlng, {
              icon: App.Utils.getLeafletMarkerHTML(feature.properties.feature_color || feature.properties.color || self.defaultFeatureColor, feature.properties.feature_icon_name),
            });
          },
          style: function (feature) {
            return {
              weight: 2,
              color: self.adminEditor ? "#ff0000" : feature.properties.feature_color || feature.properties.color || App.Utils.getBrandColor()
            };
          },
          onEachFeature: function (feature, layer) {
            if (self.editable) {
              self.setupEventListenersForEditableFeature(self.map, layer)
              self.editableLayers.push(layer);

              layer.on('pm:edit', function(e) {
                self.updateFeaturesInput(self.featuresInput, self.editableLayers);
              });
            } else {
              if (feature.geometry.type === 'Point') {
                self.clusterGroup.addLayer(layer);
              } else {
                self.deflateFeatures.addLayer(layer);
              }

              if (self.process && App.MapPopup.excludedProcesses.indexOf(self.process) === -1) {
                layer.options.resource_type = feature.properties.resource_type || null;
                layer.options.id = feature.properties.id || null;
                layer.options.feature_color = feature.properties.feature_color || self.defaultFeatureColor;
                layer.options.feature_icon_name = feature.properties.feature_icon_name || 'circle';
                layer.options.feature_category_name = feature.properties.feature_category_name || null;

                layer.on("click", self.openMarkerPopup);
              }
            }
          }
        });
      }
      if (this.editingProjektMap) {
        this.placeCenterMarker(this.mapCenterLatLng, this);
      }
    }

    openMarkerPopup(e) {
      const resourceType = e.target.options.resource_type;
      const route = App.MapPopup.getPopupDataUrl(resourceType, e.target.options);
      const properties = { feature_color: e.target.options.feature_color, feature_icon_name: e.target.options.feature_icon_name, feature_category_name: e.target.options.feature_category_name };

      if (!route) return;

      $.ajax(route, {
        type: "GET",
        dataType: "json",
        success: (data) => {
          e.target.bindPopup(
            App.MapPopup.generatePopupContent(data, resourceType, properties),
            { autoPanPadding: [0, 80], minWidth: 200, offset: L.point(0, -30) }
          ).openPopup();
        }
      });
    }

    setupEditingControls() {
      if (!this.editable)  return;

      const self = this;

      this.map.pm.setLang('de');

      this.map.pm.Toolbar.setBlockPosition('custom', 'topright');
      this.map.pm.Toolbar.setBlockPosition('draw', 'topright');
      this.map.pm.Toolbar.setBlockPosition('edit', 'topright');

      // Ads geoman controls to the map, changing some defaults
      this.map.pm.addControls({
        drawCircleMarker: false,
        drawText: false,
        removalMode: false,
        drawPolyline: this.enableShapes,
        drawRectangle: this.enableShapes,
        drawPolygon: this.enableShapes,
        drawCircle: this.enableShapes,
        editMode: this.enableShapes,
        dragMode: false,
        cutPolygon: this.enableShapes,
        rotateMode: this.enableShapes
      })

      this.map.pm.enableDraw('Marker');

      if (this.editingProjektMap) {
        this.map.pm.Toolbar.createCustomControl({
          name: 'centerMarker',
          className: 'control-icon circle leaflet-pm-icon-circle-marker',
          title: 'Zentrum markieren',
          block: 'custom',
          toggle: true,
          onClick: function() {
            const isToggled = !self.map.pm.Toolbar.buttons.centerMarker.toggled();

            if (isToggled) {
              self.map.on('click', function(e) {
                self.placeCenterMarker(e.latlng, self);
              });
            } else {
              self.map.off('click');
            }
          }
        })
      }

      if (this.enableShapes || this.adminEditor) {
        this.map.pm.Toolbar.createCustomControl({
          name: 'customDragMode',
          className: 'control-icon leaflet-pm-icon-custom-drag',
          block: 'edit',
          title: 'Auswahl modus',
          disableGlobalEditMode: true
        });

        this.map.pm.Toolbar.createCustomControl({
          name: 'clearMap',
          className: 'control-icon leaflet-pm-icon-delete',
          title: 'Karte zurücksetzen',
          block: 'edit',
          onClick: () => {
            self.editableLayers.forEach(function(layer) {
              self.map.removeLayer(layer);
            });

            self.editableLayers = [];
            self.featuresInput.value = JSON.stringify({});
          }
        });
      }

      this.rearrangeEditingControls();
      App.Map.setupEventListenersForMarkerStyleChanges(this);
      this.setupEventListenersForNewFeatures();
    }

    rearrangeEditingControls() {
      const editToolbar = this.element.querySelector('.leaflet-pm-toolbar.leaflet-pm-edit')
      if ( !editToolbar ) return;

      const customDragButtonContainer = editToolbar.querySelector('.leaflet-pm-icon-custom-drag').closest('.button-container');
      if ( !customDragButtonContainer ) return;

      editToolbar.insertBefore(customDragButtonContainer, editToolbar.firstChild);
    }

    placeCenterMarker(centerLatLng, instance) {
      if (instance.centerMarker) {
        instance.map.removeLayer(instance.centerMarker);
      }

      const centerMarker = L.marker(centerLatLng, {
        draggable: true,
        icon: App.Utils.getLeafletMarkerHTML()
      })

      instance.centerMarker = centerMarker;
      instance.map.addLayer(centerMarker);
      instance.latitudeInput.value = centerMarker.getLatLng().lat.toFixed(6);
      instance.longitudeInput.value = centerMarker.getLatLng().lng.toFixed(6);
    }

    setupEventListenersForEditableFeature(map, layer) {
      layer.on('click', function() {
        if (!map.pm.globalDrawModeEnabled() && !map.pm.globalDragModeEnabled() && !layer.pm.enabled()) {
          layer.pm.enable({ allowSelfIntersection: false });
        }
      });

      map.on('click', function(e) {
        const isMarker = layer instanceof L.Marker;

        if (!isMarker && layer.pm.enabled() && !layer.getBounds().contains(e.latlng)) {
          layer.pm.disable();
        }
      });

      layer.on("pm:drawstart", function() { layer.pm.disable() });
      layer.on("pm:dragenable", function() { layer.pm.disable() });
    }

    setupEventListenersForUpdatingFormInputs() {
      if (!this.editable) return;

      const self = this;

      this.map.on('move', function() {
        if (!self.editingProjektMap) {
          self.latitudeInput.value = self.map.getCenter().lat.toFixed(6);
          self.longitudeInput.value = self.map.getCenter().lng.toFixed(6);
          self.zoomInput.value = self.map.getZoom();
        }
      });

      this.map.on('zoomend', function() {
        self.zoomInput.value = self.map.getZoom();
      });

      this.map.on('pm:create', function(e) {
        if (!self.adminEditor && self.editableLayers.length >= self.editableLayersLimit) {
          self.map.removeLayer(self.editableLayers.pop());
        }

        self.editableLayers.push(e.layer);

        e.layer.on('pm:edit', function(e) {
          self.updateFeaturesInput(self.featuresInput, self.editableLayers);
        });

        self.updateFeaturesInput(self.featuresInput, self.editableLayers);
        self.zoomInput.value = self.map.getZoom();
      });

      this.map.on('pm:dragend', function(e) {
        if (!self.editingProjektMap) {
          self.latitudeInput.value = self.map.getCenter().lat.toFixed(6);
          self.longitudeInput.value = self.map.getCenter().lng.toFixed(6);
          self.zoomInput.value = self.map.getZoom();
        }
      });
    }

    updateFeaturesInput(featuresInput, editableLayers) {
      L.Layer.include({
        toGeoJSONWithOptions: function() {
          const layer = this;
          const allowedOptions = ['feature_color', 'feature_icon_name', 'feature_category_name'];
          const geojson = this.toGeoJSON();
          geojson.properties = geojson.properties || {};

          allowedOptions.forEach( function(option) {
            if ( option in layer.options ) {
              geojson.properties[option] = layer.options[option];
            }
          })
          return geojson;
        }
      })

      const featuresData = editableLayers.map(function(layer) {
        if ( layer.options.shape == 'Circle' ) {
          return L.PM.Utils.circleToPolygon(layer, 60).toGeoJSONWithOptions();
        } else {
          return layer.toGeoJSONWithOptions();
        }
      })

      var featureCollection = {
        type: 'FeatureCollection',
        features: featuresData
      };

      featuresInput.value = JSON.stringify(featureCollection);
    }

    toggleControlVisibility() {
      const layerControl = this.element.querySelector('.leaflet-control-layers');
      const locateControl = this.element.querySelector('.leaflet-control-locate');
      const geoSearchControl = this.element.querySelector('.leaflet-control-container > .leaflet-control-geosearch.leaflet-geosearch-bar');

      if ( this.element.offsetWidth < 700 ) {
        [layerControl, locateControl, geoSearchControl].forEach(control => {
          if (control) control.style.display = 'none';
        });
      } else {
        [layerControl, locateControl, geoSearchControl].forEach(control => {
          if (control) control.style.display = '';
        });
      }
    }

    setupEventListenersForUpdatingMapCenter() {
      if (!this.editable) return;

      const selectElement = document.querySelector('.js-update-map-center');
      if ( !selectElement ) return;

      selectElement.addEventListener('change', (event) => {
        const selectedOption = event.target.selectedOptions[0];
        const latitude = selectedOption.dataset.latitude || event.target.dataset.defaultLatitude || this.mapCenterLatitude;
        const longitude = selectedOption.dataset.longitude || event.target.dataset.defaultLongitude || this.mapCenterLongitude;

        if (latitude && longitude) {
          const newCenter = new L.LatLng(latitude, longitude);
          this.map.setView(newCenter, this.map.getZoom());
        }
      });
    }
  }

  window.App.LeafletMapController = LeafletMapController;
}).call(this);

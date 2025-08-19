(function() {
  "use strict";

  class LeafletMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();
      this.bindEventListeners();

      this.createMap();
      this.setupLayers();
      this.setupPlugins();
      this.renderFeatures();

      this.setupEditingControls();
      this.setupEventListenersForNewFeatures();
      this.setupEventListenersForUpdatingFormInputs();
    }

    initializeProperties() {
      const $element = $(this.element);

      // Map configuration
      this.mapCenterLatitude = $element.data("map-center-latitude");
      this.mapCenterLongitude = $element.data("map-center-longitude");
      this.mapCenterLatLng = new L.LatLng(this.mapCenterLatitude, this.mapCenterLongitude);
      this.zoom = $element.data("map-zoom");

      // Layer configuration
      this.layersData = $element.data('layers-data');
      this.baseLayers = {};
      this.overlayLayers = {};
      this.adminFeatures = $element.data("admin-features");

      // Features configuration
      this.features = $element.data("features");

      // Editing configuration
      this.editable = $element.data("editable");
      this.adminEditor = $element.data("admin-editor");
      this.enableShapes = $element.data("enable-shapes");
      this.editableLayers = [];
      this.centerMarker = null;

      // Form inputs
      this.latitudeInput = document.querySelector('[data-latitude-input-for="' + this.element.id + '"]');
      this.longitudeInput = document.querySelector('[data-longitude-input-for="' + this.element.id + '"]');
      this.zoomInput = document.querySelector('[data-zoom-input-for="' + this.element.id + '"]');
      this.featuresInput = document.querySelector('[data-features-input-for="' + this.element.id + '"]');
    }

    bindEventListeners() {
      // this.moveOrPlaceCenterMarker = this.moveOrPlaceCenterMarker.bind(this);
      // this.placeMultiMarker = this.placeMultiMarker.bind(this);
      // this.openMarkerPopup = this.openMarkerPopup.bind(this);
    }

    createMap() {
      const defaultColor = this.adminEditor ? "#ff0000" : App.Utils.getBrandColor()

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
          icon: App.Utils.getLeafletMarkerHTML(undefined, this.adminEditor),
        },
        pathOptions: {
          weight: 2,
          color: defaultColor,
          opacity: 1,
          fillColor: defaultColor,
          fillOpacity: 0.2
        },
        templineStyle: { color: defaultColor, dashArray: '5, 10' },
        hintlineStyle: { color: defaultColor, dashArray: '5, 10' }
      });
    }

    setupEventListenersForNewFeatures() {
      const self = this;

      self.map.on('pm:create', function(e) {
        self.setupEventListenersForEditableFeature(self.map, e.layer);
      })
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
      // Leaflet.Locate plugin
      L.control.locate({
        icon: 'fa fa-map-marker',
        strings: {
          title: 'Meine Position anzeigen'
        }
      }).addTo(this.map);

      // Leaflet GeoSearch plugin
      const searchControl = new GeoSearch.GeoSearchControl({
        provider: new GeoSearch.OpenStreetMapProvider(),
        style: 'bar',
        showMarker: false,
        searchLabel: 'Nach Adresse suchen',
        notFoundMessage: 'Entschuldigung! Die Adresse wurde nicht gefunden.',
        clearSearchLabel: 'Suche zurücksetzen'
      });
      this.map.addControl(searchControl);

      // Leaflet.Deflate plugin
      this.deflateFeatures = L.deflate({
        minSize: 10,
        markerLayer: this.markersGroup,
        markerOptions: (shape) => {
          return {
            icon: this.getMarkerIcon(shape.feature.color, shape.feature.fa_icon_class),
            id: this.getProcessId(shape)
          }
        }
      });
      this.deflateFeatures.addTo(this.map);
    }

    renderFeatures() {
      if (this.features && Object.keys(this.features).length > 0) {
        const self = this;

        this.featuresLayer = L.geoJSON(this.features, {
          pointToLayer: function(feature, latlng) {
            return L.marker(latlng, {
              icon: App.Utils.getLeafletMarkerHTML(feature, self.adminEditor),
            });
          },
          style: function (feature) {
            return {
              weight: 2,
              color: self.adminEditor ? "#ff0000" : feature.properties.color || App.Utils.getBrandColor()
            };
          },
          onEachFeature: function (feature, layer) {
            if (self.editable) {
              self.setupEventListenersForEditableFeature(self.map, layer)

              layer.on('pm:edit', function(e) {
                self.updateFeaturesInput(self.featuresInput, self.editableLayers);
              });

              self.editableLayers.push(layer);
            }
          }
        }).addTo(this.map);
      }
    }

    setupEditingControls() {
      if (!this.editable)  return;

      const self = this;

      this.map.pm.setLang('de');

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
        dragMode: this.enableShapes,
        cutPolygon: this.enableShapes,
        rotateMode: this.enableShapes,
        positions: {
          custom: 'topright',
          edit: 'topright',
          draw: 'topright'
        }
      })

      if (this.adminEditor) {
        this.map.pm.Toolbar.createCustomControl({
          name: 'centerMarker',
          className: 'control-icon circle leaflet-pm-icon-circle-marker',
          title: 'Zentrum markieren',
          block: 'custom',
          onClick: function() {
            console.log('Zentrum markieren');

            self.map.on('click', function(e) {
              const centerMarker = L.marker(e.latlng, {
                draggable: true,
                icon: App.Utils.getLeafletMarkerHTML(undefined, self.adminEditor)
              })

              if (self.centerMarker) {
                self.map.removeLayer(self.centerMarker);
              }

              self.centerMarker = centerMarker;
              self.map.addLayer(centerMarker);
              self.latitudeInput.value = centerMarker.getLatLng().lat.toFixed(6);
              self.longitudeInput.value = centerMarker.getLatLng().lng.toFixed(6);
            })
          }
        })
      }

      if (this.enableShapes || this.adminEditor) {
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
        if (!self.adminEditor) {
          self.latitudeInput.value = self.map.getCenter().lat.toFixed(6);
          self.longitudeInput.value = self.map.getCenter().lng.toFixed(6);
        }
      });

      this.map.on('zoomend', function() {
        self.zoomInput.value = self.map.getZoom();
      });

      this.map.on('pm:create', function(e) {
        if (!self.adminEditor) {
          self.editableLayers.forEach((layer) => {
            self.map.removeLayer(layer);
          });
          self.editableLayers = [];
        }

        self.editableLayers.push(e.layer);
        self.updateFeaturesInput(self.featuresInput, self.editableLayers);
      });

      this.map.on('pm:dragend', function(e) {
        if (!self.adminEditor) {
          self.latitudeInput.value = self.map.getCenter().lat.toFixed(6);
          self.longitudeInput.value = self.map.getCenter().lng.toFixed(6);
        }
      });
    }

    updateFeaturesInput(featuresInput, editableLayers) {
      var featuresData = editableLayers.map(function(layer) {
        return layer.toGeoJSON();
      })

      var featureCollection = {
        type: 'FeatureCollection',
        features: featuresData
      };

      featuresInput.value = JSON.stringify(featureCollection);
    }
  }

  window.App.LeafletMapController = LeafletMapController;
}).call(this);

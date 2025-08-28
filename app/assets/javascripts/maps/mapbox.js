(function() {
  "use strict";

  class MapboxMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();
      this.bindEventListeners();

      this.createMap();
      // this.setupEventListenersForNewFeatures();
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

      // Form inputs
      this.latitudeInput = document.querySelector('[data-latitude-input-for="' + this.element.id + '"]');
      this.longitudeInput = document.querySelector('[data-longitude-input-for="' + this.element.id + '"]');
      this.zoomInput = document.querySelector('[data-zoom-input-for="' + this.element.id + '"]');
      this.featuresInput = document.querySelector('[data-features-input-for="' + this.element.id + '"]');

      // State variables
      this.layersRendered = false;
    }

    bindEventListeners() {
    //  this.openMarkerPopup = this.openMarkerPopup.bind(this);
    }

    initMap(callback) {
      const instance = this;

      function initMapInstance() {
        mapboxgl.accessToken = instance.element.dataset.mapboxPublicToken;
        const map = new mapboxgl.Map({
          container: instance.element,
          center: [instance.mapCenterLongitude, instance.mapCenterLatitude],
          zoom: instance.zoom,
          pitch: 53,
          preserveDrawingBuffer: true,
          style: instance.element.dataset.mapboxStyleId,
        });

        if (callback) callback(map);
      }

      if (window.mapboxgl) {
        initMapInstance();
        return;
      }

      window._mapboxMapQueue.push(initMapInstance);

      if (window._mapboxScriptsLoading) return;
      window._mapboxScriptsLoading = true;

      const cssUrls = [
        'https://api.mapbox.com/mapbox-gl-js/v3.12.0/mapbox-gl.css',
        'https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-draw/v1.5.0/mapbox-gl-draw.css',
        'https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-geocoder/v5.0.3/mapbox-gl-geocoder.css'
      ];
      cssUrls.forEach(url => {
        if (!document.querySelector(`link[href="${url}"]`)) {
          const link = document.createElement('link');
          link.rel = 'stylesheet';
          link.href = url;
          document.head.appendChild(link);
        }
      });

      const jsUrls = [
        'https://api.mapbox.com/mapbox-gl-js/v3.12.0/mapbox-gl.js',
        'https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-draw/v1.5.0/mapbox-gl-draw.js',
        'https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-geocoder/v5.0.3/mapbox-gl-geocoder.min.js'
      ];

      function loadNext(index) {
        if (index >= jsUrls.length) {
          window._mapboxMapQueue.forEach(function(initFn) { initFn(); });
          window._mapboxMapQueue = [];
          return;
        }

        const script = document.createElement('script');
        script.src = jsUrls[index];
        script.async = false; // preserve order
        script.onload = function() { loadNext(index + 1); };
        document.head.appendChild(script);
      }

      loadNext(0);
    }

    createMap() {
      const instance = this;
      const defaultColor = this.adminEditor ? "#ff0000" : App.Utils.getBrandColor()
      window._mapboxMapQueue = window._mapboxMapQueue || [];

      this.initMap(function(map) {
        instance.map = map;
        instance.setupPlugins();
        instance.setupLayers();
        instance.setupEditingControls();
        instance.setupEventListenersForUpdatingFormInputs();
        instance.renderFeatures();
      });


    //  if (this.editableLayersLimit && this.editableLayersLimit > 1) {
    //    this.addHintAboutEditableLayersLimit();
    //  }
    }

    setupEventListenersForNewFeatures() {
    //  const self = this;

    //  self.map.on('pm:create', function(e) {
    //    if (e.shape === 'Circle') {
    //      e.layer.options.shape = 'Circle';
    //    }

    //    self.setupEventListenersForEditableFeature(self.map, e.layer);
    //  })
    }

    setupLayers() {
      const instance = this;

      instance.map.on('style.load', function() {
        if (!instance.layersRendered) {
          instance.layersRendered = true;

          instance.addLayerControl();

          if (instance.adminFeatures && Object.keys(instance.adminFeatures).length > 0) {
            instance.addAdminFeaturesAsLayer();
          };

          instance.layersData.forEach(function(layerData) {
            instance.createLayer(layerData);
            instance.addLayerToControl(layerData);
          });
        }
      });
    }

    addLayerControl() {
      if (this.element.offsetWidth <= 780) {
        return;
      }

      this.layerControl = new LayerControl(this);
      this.map.addControl(this.layerControl, 'top-right');
    }

    createLayer(layerData) {
      const sourceId = 'ext-layersource-' + layerData.id;

      if (layerData.protocol === 'wms') {
        const baseUrl = layerData.provider;
        const separator = baseUrl.includes('?') ? '&' : '?';
        const wmsParams = [
                'service=WMS',
                'request=GetMap',
                'layers=' + layerData.layer_names,
                'format=image/png',
                'styles=',
                'transparent=' + (layerData.transparent ? 'true' : 'false'),
                'version=1.1.1',
                "show_by_default=false",
                'width=256',
                'height=256',
                'srs=EPSG:3857',
                'bbox={bbox-epsg-3857}',
              ];

        const wmsUrl = baseUrl + separator + wmsParams.join('&');

        this.map.addSource(sourceId, {
          type: 'raster',
          tiles: [wmsUrl],
          tileSize: 256
        });

        this.map.addLayer({
          id: 'ext-layer-' + layerData.id,
          type: 'raster',
          source: sourceId,
          paint: {
            'raster-opacity': parseFloat(layerData.opacity) || 1
          },
          layout: {
            visibility: layerData.show_by_default ? 'visible' : 'none'
          }
        });
      }
    }

    addLayerToControl(layerData) {
      const isVisible = layerData.show_by_default || layerData.id === this.layersData[0].id;
      const label = this.layerControl.createLayerCheckbox(
        layerData.name,
        'ext-layer-' + layerData.id,
        isVisible,
        layerData.type === 'base' ? 'radio' : 'checkbox'
      );

      this.layerControl.dropdownList.appendChild(label);
    }

    toggleLayer(layerId, map, visible) {
      const layers = map.getStyle().layers;
      const visibility = visible ? 'visible' : 'none';

      layers.forEach((layer) => {
        if (layer.id === layerId) {
            map.setLayoutProperty(layer.id, 'visibility', visibility);
        }
      });
    }

    ensureBaseLayerExistence() {
    //  if (Object.keys(this.baseLayers).length === 0) {
    //    const defaultLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    //      attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
    //    });
    //    this.baseLayers['defaultLayer'] = defaultLayer;
    //  }
    }

    addAdminFeaturesAsLayer() {
      const instance = this;

      if (!instance.map.getSource('admin-features')) {
        instance.map.addSource('admin-features', {
          type: 'geojson',
          data: instance.adminFeatures
        });

        instance.map.addLayer({
          id: 'admin-features-circles',
          type: 'circle',
          source: 'admin-features',
          filter: ['==', '$type', 'Point'],
          paint: {
            'circle-radius': 6,
            'circle-color': '#ff0000',
          }
        });

        instance.map.addLayer({
          id: 'admin-features-lines',
          type: 'line',
          source: 'admin-features',
          filter: ['==', '$type', 'LineString'],
          layout: {
            'line-join': 'round',
            'line-cap': 'round'
          },
          paint: {
            'line-color': '#ff0000',
            'line-width': 4
          }
        });

        instance.map.addLayer({
          id: 'admin-features-polygons',
          type: 'fill',
          source: 'admin-features',
          filter: ['==', '$type', 'Polygon'],
          layout: {},
          paint: {
            'fill-color': '#ff0000',
            'fill-opacity': 0.2
          }
        });
      }

      // add to layer control
      const label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      const input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = true;

      const span = document.createElement('span');
      span.textContent = 'Verwaltungseinträge';

      label.appendChild(input);
      label.appendChild(span);

      input.addEventListener('change', () => {
        instance.toggleLayer('admin-features-circles', instance.map, input.checked);
        instance.toggleLayer('admin-features-lines', instance.map, input.checked);
        instance.toggleLayer('admin-features-polygons', instance.map, input.checked);
      });

      this.layerControl.dropdownList.appendChild(label);

    //  const adminFeaturesLayer = L.geoJSON(this.adminFeatures, {
    //    pointToLayer: function(feature, latlng) {
    //      return L.marker(latlng, {
    //        icon: App.Utils.getLeafletMarkerHTML('#ff0000')
    //      });
    //    },
    //    onEachFeature: (feature, layer) => {
    //      layer.bindPopup('<div class="map-popup-status-message">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>');
    //      layer.pm.disable();
    //      layer.pm.setOptions({
    //        draggable: false,
    //        editable: false
    //      });
    //    }
    //  }).addTo(this.map);
    //  this.overlayLayers['Verwaltungseinträge'] = adminFeaturesLayer;
    //  this.renderAdminFeaturesNote();
    }

    addHintAboutEditableLayersLimit() {
    //  const hintText = 'Sie dürfen insgesamt ' + this.editableLayersLimit + ' Pins setzen.'
    //  const hintControl = L.control({
    //    position: 'bottomleft'
    //  })

    //  hintControl.onAdd = () => {
    //    const container = L.DomUtil.create('div', 'feature-limit-hint');
    //    container.innerHTML = hintText;
    //    container.className += ' leaflet-control-attribution';
    //    container.style.color = '#ff0000';
    //    return container;
    //  };

    //  hintControl.addTo(this.map);
    }

    renderAdminFeaturesNote() {
    //  const adminShapeExplainerText = 'Alle markierten Flächen und Pins in rot sind vom System vorgegeben';
    //  const adminShapeExplainer = L.control({
    //    position: 'bottomleft'
    //  });

    //  adminShapeExplainer.onAdd = () => {
    //    const container = L.DomUtil.create('div', 'my-attribution');
    //    container.innerHTML = adminShapeExplainerText;
    //    container.className += ' leaflet-control-attribution';
    //    container.style.color = '#ff0000';
    //    return container;
    //  };

    //  adminShapeExplainer.addTo(this.map);
    }

    setupPlugins() {
      if (this.placement == 'sidebar') return;

      this.map.addControl(new mapboxgl.NavigationControl(), 'top-left');
      this.map.addControl(new MapboxGeocoder({
          accessToken: mapboxgl.accessToken,
          mapboxgl: mapboxgl,
          countries: 'DE',
          marker: false
      }), 'top-left');
      this.map.addControl(new mapboxgl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        trackUserLocation: true
        }), 'top-left'
      );
    }

    formattedFeaturesForRendering() {
      if (Array.isArray(this.features)) {
        // Merge multiple FeatureCollections into one
        let merged = {
          type: 'FeatureCollection',
          features: []
        };

        this.features.forEach(function(fc) {
          if (fc && fc.type === 'FeatureCollection' && Array.isArray(fc.features)) {
            Array.prototype.push.apply(merged.features, fc.features);
          } else {
            console.warn('Invalid FeatureCollection:', fc);
          }
        });

        return merged;
      } else {
        // Assume it's already a FeatureCollection
        return this.features;
      }
    }

    renderFeatures() {
      if (this.features && Object.keys(this.features).length > 0) {
        const instance = this;

        if (instance.editable) {
          instance.features.features.forEach(function(feature) {
            instance.editableLayers.push(feature.id);
            instance.draw.add(feature);
          });

          instance.map.on('draw.update', function(e) {
            instance.updateFeaturesInput(instance.featuresInput, instance.editableLayers);
          });

        } else {

          instance.map.on('style.load', function() {
            if (!instance.map.getSource('user-features')) {
              instance.map.addSource('user-features', {
                type: 'geojson',
                data: instance.formattedFeaturesForRendering()
              });

              instance.map.addLayer({
                id: 'user-features-circles-outer',
                type: 'circle',
                source: 'user-features',
                filter: ['==', '$type', 'Point'],
                paint: { 'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 15, 15 ], 'circle-color': instance.defaultFeatureColor }
              });

              instance.map.addLayer({
                id: 'user-features-circles-inner',
                type: 'circle',
                source: 'user-features',
                filter: ['==', '$type', 'Point'],
                paint: { 'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 12, 12 ], 'circle-color': '#fff' }
              });

              instance.map.addLayer({
                id: 'user-features-lines',
                type: 'line',
                source: 'user-features',
                filter: ['==', '$type', 'LineString'],
                layout: {
                  'line-join': 'round',
                  'line-cap': 'round'
                },
                paint: {
                  'line-color': ['coalesce', ['get', 'color'], instance.defaultFeatureColor],
                  'line-width': 4
                }
              });

              instance.map.addLayer({
                id: 'user-features-polygons',
                type: 'fill',
                source: 'user-features',
                filter: ['==', '$type', 'Polygon'],
                layout: {},
                paint: {
                  'fill-color': ['coalesce', ['get', 'color'], instance.defaultFeatureColor],
                  'fill-opacity': 0.5
                }
              });

              if (instance.process && App.MapPopup.excludedProcesses.indexOf(instance.process) === -1) {
                const userFeaturesLayers = ['user-features-circles-outer', 'user-features-circles-inner', 'user-features-lines', 'user-features-polygons'];
                userFeaturesLayers.forEach(function(layerId) {
                  instance.map.on('click', layerId, instance.openMarkerPopup);
                })
              }
            }
          });
        }
      }

      if (this.editingProjektMap) {
        this.placeCenterMarker(this.mapCenterLatLng, this);
      }
    }

    openMarkerPopup(e) {
      if (!e.features || !e.features.length || !e.features[0]) {
        console.warn("No features found in popup event:", e);
        return;
      }

      const coordinates = e.features[0].geometry.coordinates.slice();
      const properties = e.features[0].properties;
      const resourceType = properties["resource_type"]

      // Show empty popup immediately
      var popup = new mapboxgl.Popup({
        offset: 20,
        closeButton: true,
        maxWidth: '250px'
      })
        .setLngLat(coordinates[0][0] || coordinates)
        .setHTML('<div class="map-popup-status-message">Laden...</div>')
        .addTo(this);

      var popupDataUrl = App.MapPopup.getPopupDataUrl(resourceType, properties)

      if (!popupDataUrl) return;

      $.ajax(popupDataUrl, {
        type: "GET",
        dataType: "json"
      })
        .then(function(data) {
          popup.setHTML(App.MapPopup.generatePopupContent(data, resourceType));
        })
        .fail(function() {
          popup.setHTML('<div class="map-popup-status-message error">Failed to load data</div>');
        })
    }

    setupEditingControls() {
      if (!this.editable)  return;

      const controls = {
        point: true
      }

      if (this.enableShapes) {
        controls.trash = true;
        controls.line_string = true;
        controls.polygon = true;
      }

      this.draw = new MapboxDraw({
        displayControlsDefault: false,
        controls: controls,
        defaultMode: 'draw_point',
        styles: this.getDrawStyles()
      });

      this.map.addControl(this.draw);
      // this.addCustomDeleteButton();
      // this.loadExistingShape();

      // this.setupDrawEventListeners();
      // this.setupDrawCursorEffects();
    }

    getDrawStyles() {
      return [
        {
          'id': 'gl-draw-polygon-fill',
          'type': 'fill',
          'filter': [ 'all',
            ['==', '$type', 'Polygon']
          ],
          'paint': {
            'fill-color': [ 'case', ['==', ['get', 'active'], 'true'], this.defaultFeatureColor, this.defaultFeatureColor ],
            'fill-opacity': [ 'case', ['==', ['get', 'active'], 'true'], 0.35, 0.15 ]
          }
        },
        {
          'id': 'gl-draw-lines',
          'type': 'line',
          'filter': [ 'any',
            ['==', '$type', 'LineString'],
            ['==', '$type', 'Polygon'],
          ],
          'layout': {
            'line-cap': 'round',
            'line-join': 'round',
          },
          'paint': {
            'line-color': [ 'case', ['==', ['get', 'active'], 'true'], this.defaultFeatureColor, this.defaultFeatureColor ],
            'line-dasharray': [ 'case', ['==', ['get', 'active'], 'true'], [5, 5], [5, 0] ],
            'line-width': [ 'case', ['==', ['get', 'active'], 'true'], 2, 2 ]
          },
        },
        {
          'id': 'gl-draw-point-outer',
          'type': 'circle',
          'filter': [ 'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'feature'],
          ],
          'paint': {
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 17, 15 ],
            'circle-color': this.defaultFeatureColor
          },
        },
        {
          'id': 'gl-draw-point-inner',
          'type': 'circle',
          'filter': [ 'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'feature'],
          ],
          'paint': {
            'line-color': [ 'case', ['==', ['get', 'active'], 'true'], '#fff', '#fff' ],
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 12, 12],
            'circle-color': [ 'case', ['==', ['get', 'active'], 'true'], '#fff', '#fff' ],
          },
        },

        {
          'id': 'gl-draw-vertex-outer',
          'type': 'circle',
          'filter': [ 'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'vertex'],
            ['!=', 'mode', 'simple_select'],
          ],
          'paint': {
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 8, 9],
            'circle-color': this.defaultFeatureColor
          },
        },
        {
          'id': 'gl-draw-vertex-inner',
          'type': 'circle',
          'filter': [ 'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'vertex'],
            ['!=', 'mode', 'simple_select'],
          ],
          'paint': {
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 5, 7],
            'circle-color': "#fff"
          },
        },
      ];
    }

    placeCenterMarker(centerLatLng, instance) {
    //  if (instance.centerMarker) {
    //    instance.map.removeLayer(instance.centerMarker);
    //  }

    //  const centerMarker = L.marker(centerLatLng, {
    //    draggable: true,
    //    icon: App.Utils.getLeafletMarkerHTML()
    //  })

    //  instance.centerMarker = centerMarker;
    //  instance.map.addLayer(centerMarker);
    //  instance.latitudeInput.value = centerMarker.getLatLng().lat.toFixed(6);
    //  instance.longitudeInput.value = centerMarker.getLatLng().lng.toFixed(6);
    }

    setupEventListenersForEditableFeature(map, layer) {
    //  layer.on('click', function() {
    //    if (!map.pm.globalDrawModeEnabled() && !map.pm.globalDragModeEnabled() && !layer.pm.enabled()) {
    //      layer.pm.enable({ allowSelfIntersection: false });
    //    }
    //  });

    //  map.on('click', function(e) {
    //    const isMarker = layer instanceof L.Marker;

    //    if (!isMarker && layer.pm.enabled() && !layer.getBounds().contains(e.latlng)) {
    //      layer.pm.disable();
    //    }
    //  });

    //  layer.on("pm:drawstart", function() { layer.pm.disable() });
    //  layer.on("pm:dragenable", function() { layer.pm.disable() });
    }

    setupEventListenersForUpdatingFormInputs() {
      if (!this.editable) return;

      const instance = this;

      this.map.on('moveend', function() {
        if (!instance.editingProjektMap) {
          instance.latitudeInput.value = instance.map.getCenter().lat.toFixed(6);
          instance.longitudeInput.value = instance.map.getCenter().lng.toFixed(6);
          instance.zoomInput.value = instance.map.getZoom();
        }
      });

      this.map.on('zoomend', function() {
        instance.zoomInput.value = instance.map.getZoom();
      });

      this.map.on('draw.create', function(e) {
        const currentMode = instance.draw.getMode();
        const newFeature = e.features[0];

        if (!instance.adminEditor && instance.editableLayers.length >= instance.editableLayersLimit) {
          instance.draw.delete(instance.editableLayers.pop());
        }

        setTimeout(() => {
          instance.draw.changeMode(currentMode);
        }, 0);

        instance.editableLayers.push(newFeature.id);
        instance.updateFeaturesInput(instance.featuresInput, instance.editableLayers);
        instance.zoomInput.value = instance.map.getZoom();
      });

      this.map.on('draw.delete', function(e) {
        e.features.forEach(function(feature) {
          instance.editableLayers = instance.editableLayers.filter(function(id) { return id !== feature.id; });
          instance.draw.delete(feature.id);
        });

        instance.updateFeaturesInput(instance.featuresInput, instance.editableLayers);
      });

      this.map.on('dragend', function(e) {
        if (!instance.editingProjektMap) {
          instance.latitudeInput.value = instance.map.getCenter().lat.toFixed(6);
          instance.longitudeInput.value = instance.map.getCenter().lng.toFixed(6);
          instance.zoomInput.value = instance.map.getZoom();
        }
      });
    }

    updateFeaturesInput(featuresInput, editableLayers) {
      const featuresData = this.draw.getAll().features.filter( function(feature) {
        return editableLayers.includes(feature.id);
      })

      const featureCollection = {
        type: 'FeatureCollection',
        features: featuresData
      };

      featuresInput.value = JSON.stringify(featureCollection);
    }
  }

  // Custom control for layer visibility toggle
  class LayerControl {
    constructor(mapboxMapInstance) {
      this.mapboxMapInstance = mapboxMapInstance;
    }

    onAdd(map) {
      this._map = map;
      this._container = document.createElement('div');
      this._container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group mapbox-layer-control';

      // Create button to toggle dropdown
      let button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-layer-control-button';
      button.innerHTML = '<i class="fas fa-layer-group"></i>'; // Layers icon
      button.title = 'Kartenebenen';

      // Create dropdown container
      let dropdown = document.createElement('div');
      dropdown.className = 'mapbox-layer-control-dropdown';
      dropdown.style.display = 'none';

      // Add POI labels section
      this.dropdownList = document.createElement('div');
      this.dropdownList.className = 'mapbox-layer-select-section';

      let dropdownTitle = document.createElement('div');
      dropdownTitle.className = 'mapbox-layer-select-section-title';
      dropdownTitle.textContent = 'Kartenebenen';
      this.dropdownList.appendChild(dropdownTitle);

      let poiLabel = this.createPoiCheckbox();
      this.dropdownList.appendChild(poiLabel);
      dropdown.appendChild(this.dropdownList);

      this._container.appendChild(button);
      this._container.appendChild(dropdown);

      // Toggle dropdown on button click
      button.addEventListener('click', (e) => {
        e.stopPropagation();
        dropdown.style.display = dropdown.style.display === 'none' ? 'block' : 'none';
      });

      // Close dropdown when clicking outside
      document.addEventListener('click', (e) => {
        if (!this._container.contains(e.target)) {
          dropdown.style.display = 'none';
        }
      });

      return this._container;
    }

    createLayerCheckbox(name, layerId, isChecked, inputType) {
      let label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      let input = document.createElement('input');
      input.type = inputType;
      input.checked = isChecked;
      if (inputType === 'radio') {
        input.name = 'base-layer';
      }

      let span = document.createElement('span');
      span.textContent = name;

      label.appendChild(input);
      label.appendChild(span);

      input.addEventListener('change', () => {
        if (inputType === 'radio' && input.checked) {
          Object.values(this.mapboxMapInstance.baseLayers).forEach(layer => {
            this.mapboxMapInstance.toggleLayer(layer.layerId, this.mapboxMapInstance.map, false);
          });
          this.mapboxMapInstance.toggleLayer(layerId, this.mapboxMapInstance.map, true);
        } else if (inputType === 'checkbox') {
          this.mapboxMapInstance.toggleLayer(layerId, this.mapboxMapInstance.map, input.checked);
        }
      });

      return label;
    }

    createPoiCheckbox() {
      let label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      let input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = true; // Default to on

      let span = document.createElement('span');
      span.textContent = 'Orte von Interesse';

      label.appendChild(input);
      label.appendChild(span);

      // Handle POI labels visibility changes
      input.addEventListener('change', () => {
        this.mapboxMapInstance.toggleLayer('poi-label', this.mapboxMapInstance.map, input.checked);
      });

      return label;
    }

    onRemove() {
      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
    }
  }

  window.App.MapboxMapController = MapboxMapController;
}).call(this);

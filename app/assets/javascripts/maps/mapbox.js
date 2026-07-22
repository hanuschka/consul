(function() {
  "use strict";

  class MapboxMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();

      this.createMap();
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
      this.masterportalPinsLayerLabel = $element.data("masterportal-pins-layer-label") || "Masterportal-Pins";
      this.masterportalDefaultIconUrl = $element.data("masterportal-default-icon-url");

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
      this.currentMarker = null;
      this.defaultFeatureColor = this.adminEditor ? "#ff0000" : App.Utils.getBrandColor();
      this.featureColor = null;
      this.featureIconName = null;
      this.featureIconUnicode = null;
      this.featureCategoryName = null;


      // Form inputs
      this.latitudeInput = document.querySelector('[data-latitude-input-for="' + this.element.id + '"]');
      this.longitudeInput = document.querySelector('[data-longitude-input-for="' + this.element.id + '"]');
      this.zoomInput = document.querySelector('[data-zoom-input-for="' + this.element.id + '"]');
      this.featuresInput = document.querySelector('[data-features-input-for="' + this.element.id + '"]');
    }

    // Public Interface method for assistant map update and external use
    // DO NOT DELETE
    setMarkerTo(lat, lng, shouldScroll) {
      this.map.flyTo({
        center: [lng, lat],
        duration: 1000
      });

      this.moveOrPlaceMarker(lat, lng);

      if (shouldScroll) {
        this.map.getContainer().scrollIntoView({
          block: "center", inline: "nearest"
        })
      }
    }

    initMap(callback) {
      const instance = this;
      this.initialPitch = 10;

      function initMapInstance() {
        mapboxgl.accessToken = instance.element.dataset.mapboxPublicToken;
        const map = new mapboxgl.Map({
          container: instance.element,
          center: [instance.mapCenterLongitude, instance.mapCenterLatitude],
          zoom: instance.zoom,
          pitch: instance.initialPitch,
          preserveDrawingBuffer: true,
          style: instance.element.dataset.mapboxStyleId,
          cooperativeGestures: true,
          locale: {
            "ScrollZoomBlocker.CtrlMessage": "Zum Zoomen der Karte Strg + Scrollen verwenden",
            "ScrollZoomBlocker.CmdMessage": "⌘ gedrückt halten und scrollen, um die Karte zu zoomen",
            'TouchPanBlocker.Message': 'Zum Verschieben der Karte zwei Finger verwenden'
          },
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
        map.on('load', function() {
          instance.setupLayers();
          instance.renderFeatures();
          instance.toggleControlVisibility();
          instance.setupEditingControls();

          if (!instance.editable) {
            instance.map.keyboard.disable();
            App.MapKeyboardFocus.neutralize(instance.element);
          }
        });
        instance.addInstructionOverlay();
        instance.setupExpandControl();
        instance.addResetViewControl();
        instance.setupPlugins();
        instance.setupEventListenersForUpdatingFormInputs();
        instance.setupEventListenersForUpdatingMapCenter();
      });
    }

    whenIdle() {
      const instance = this;

      return new Promise((resolve) => {
        if (!instance.map) {
          resolve();
          return;
        }

        const waitForIdle = () => {
          if (instance.map.loaded()) {
            instance.map.once('idle', resolve);
          } else {
            instance.map.once('load', () => {
              instance.map.once('idle', resolve);
            });
          }
        };

        waitForIdle();
      });
    }

    setupExpandControl() {
      this.map.addControl(new ExpandControl(this), 'top-right');
    }

    addResetViewControl() {
      this.map.addControl(new ResetViewControl(this), 'top-right');
    }

    setupLayers() {
      const instance = this;

      instance.addLayerControl();


      if (instance.adminFeatures && Object.keys(instance.adminFeatures).length > 0) {
        instance.addAdminFeaturesAsLayer();
      };

      instance.layersData.forEach(function(layerData) {
        instance.createLayer(layerData);
        if (instance.layerControl) {
          instance.addLayerToControl(layerData);
        }
      });
    }

    addLayerControl() {
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
      } else if (layerData.protocol === 'geojson') {
        if (!layerData.data_url) return;

        const cfg = layerData.config || {};
        const layerId = 'ext-layer-' + layerData.id;
        const lineLayerId = layerId + '-line';
        const visibility = layerData.show_by_default ? 'visible' : 'none';

        this.map.addSource(sourceId, {
          type: 'geojson',
          data: layerData.data_url
        });

        // Fill layer carries the control's layerId so the checkbox toggles it.
        this.map.addLayer({
          id: layerId,
          type: 'fill',
          source: sourceId,
          paint: {
            'fill-color': this.geoJsonFillColor(cfg),
            'fill-opacity': this.geoJsonFillOpacity(cfg)
          },
          layout: { visibility: visibility }
        });

        this.map.addLayer({
          id: lineLayerId,
          type: 'line',
          source: sourceId,
          paint: {
            'line-color': (cfg.style && cfg.style.color) || '#1A3C8C',
            'line-width': this.geoJsonLineWidth(cfg)
          },
          layout: { visibility: visibility }
        });

        if (cfg.choropleth && cfg.choropleth.enabled) {
          this.addChoroplethLegend(cfg);
        }
      }
    }

    geoJsonFillOpacity(cfg) {
      const style = cfg.style || {};
      return App.Map.numberOrDefault(style.fillOpacity, 0.3);
    }

    geoJsonLineWidth(cfg) {
      return App.Map.numberOrDefault(cfg.style && cfg.style.weight, 1);
    }

    // Returns a Mapbox GL paint value for fill-color: a flat color, or a
    // data-driven "step" expression when choropleth is enabled.
    geoJsonFillColor(cfg) {
      const style = cfg.style || {};
      const ch = cfg.choropleth || {};
      const flat = style.fillColor || '#3366CC';

      if (!ch.enabled) return flat;

      const breaks = (ch.breaks || []).map(function(b) { return parseFloat(b); });
      const colors = ch.colors || [];
      if (!breaks.length || colors.length !== breaks.length + 1) return flat;

      const step = ['step', ['to-number', ['get', ch.property]], colors[0]];
      for (let i = 0; i < breaks.length; i++) {
        step.push(breaks[i], colors[i + 1]);
      }

      // null / non-numeric values fall back to the no-data color.
      return [
        'case',
        ['==', ['typeof', ['get', ch.property]], 'number'],
        step,
        ch.no_data_color || '#cccccc'
      ];
    }

    addChoroplethLegend(cfg) {
      const ch = cfg.choropleth || {};
      const breaks = ch.breaks || [];
      const colors = ch.colors || [];

      const container = document.createElement('div');
      container.className = 'map-choropleth-legend mapbox-choropleth-legend';
      // Inline styles so the legend renders without depending on map component SCSS.
      container.style.cssText = [
        'position:absolute', 'bottom:24px', 'right:8px', 'z-index:1',
        'max-width:220px', 'padding:8px 10px', 'background:#fff',
        'border-radius:4px', 'box-shadow:0 1px 4px rgba(0,0,0,0.3)',
        'font-size:12px', 'line-height:1.5'
      ].join(';');

      const rows = [];
      if (ch.legend_title) {
        rows.push('<div class="map-choropleth-legend__title"><strong>' + App.MapPopup.escapeHtml(ch.legend_title) + '</strong></div>');
      }

      for (let i = 0; i < colors.length; i++) {
        let label;
        if (i === 0) {
          label = '< ' + App.MapPopup.escapeHtml(breaks[0]);
        } else if (i === colors.length - 1) {
          label = '≥ ' + App.MapPopup.escapeHtml(breaks[breaks.length - 1]);
        } else {
          label = App.MapPopup.escapeHtml(breaks[i - 1]) + ' – ' + App.MapPopup.escapeHtml(breaks[i]);
        }

        const swatch = '<span class="map-choropleth-legend__swatch" style="display:inline-block;width:14px;height:14px;margin-right:6px;background:' + App.MapPopup.escapeHtml(colors[i]) + '"></span>';
        rows.push('<div class="map-choropleth-legend__row">' + swatch + label + '</div>');
      }

      container.innerHTML = rows.join('');
      this.element.appendChild(container);

      this._geojsonLegends = this._geojsonLegends || [];
      this._geojsonLegends.push(container);
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
        // geojson overlays add a companion outline layer that toggles in lockstep.
        if (layer.id === layerId || layer.id === layerId + '-line') {
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
          paint: { 'circle-radius': 12, 'circle-color': '#008000', 'circle-opacity': 0.5 }
        });

        instance.map.addLayer({
          id: 'admin-features-lines',
          type: 'line',
          source: 'admin-features',
          filter: ['==', '$type', 'LineString'],
          layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': '#008000', 'line-width': 4 }
        });

        instance.map.addLayer({
          id: 'admin-features-polygons',
          type: 'fill',
          source: 'admin-features',
          filter: ['==', '$type', 'Polygon'],
          layout: {},
          paint: { 'fill-color': '#008000', 'fill-opacity': 0.2 }
        });
      }

      if (this.layerControl) {

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
      }

      const popupContent = '<div class="map-popup-status-message">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>';
      instance.map.on('click', 'admin-features-circles', function(e) {
        new mapboxgl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(popupContent)
          .addTo(instance.map);
      });

      instance.map.on('click', 'admin-features-lines', function(e) {
        new mapboxgl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(popupContent)
          .addTo(instance.map);
      });

      instance.map.on('click', 'admin-features-polygons', function(e) {
        new mapboxgl.Popup()
          .setLngLat(e.lngLat)
          .setHTML(popupContent)
          .addTo(instance.map);
      });

      this.renderAdminFeaturesNote();
    }

    addInstructionOverlay() {
      const overlay = document.createElement('div');
      overlay.className = 'mapbox-instruction-overlay';

      this.element.style.position = 'relative';
      this.element.appendChild(overlay);

      this.instructionOverlay = overlay;
    }


    addHintAboutEditableLayersLimit() {
      this.instructionOverlay.insertAdjacentHTML('beforeend', '<div class="feature-limit-hint" style="color:#ff0000;">Sie dürfen insgesamt ' + this.editableLayersLimit + ' Pins setzen.');
    }

    renderAdminFeaturesNote() {
      this.instructionOverlay.insertAdjacentHTML('beforeend', '<div class="adminShapeInfo" style="color:#008000;">Alle markierten Flächen und Pins in grün sind vom System vorgegeben</div>');
    }

    setupPlugins() {
      this.map.addControl(new mapboxgl.NavigationControl(), 'top-left');
      this.map.addControl(new MapboxGeocoder({
          accessToken: mapboxgl.accessToken,
          mapboxgl: mapboxgl,
          countries: 'DE',
          marker: false,
          placeholder: 'Nach Adresse suchen'
      }), 'top-left');

      const searchInput = this.element.querySelector('.mapboxgl-ctrl-geocoder--input');
      if (searchInput) {
        searchInput.setAttribute('title', 'Nach Adresse suchen');
        searchInput.setAttribute('aria-label', 'Nach Adresse suchen');
      }

      this.map.addControl(new mapboxgl.GeolocateControl({
        positionOptions: { enableHighAccuracy: true },
        trackUserLocation: true
        }), 'top-left'
      );
    }

    renderFeatures() {
      if (this.editable) return;
      if (!this.map) return;

      if (!this.map.isStyleLoaded()) {
        this.map.once('idle', this.renderFeatures.bind(this));
        return;
      }

      if (this.map.getSource('user-features-points')) return;

      const split = App.Map.splitMasterportalFeatures(this.features);

      let pointFeatures = {
        type: 'FeatureCollection',
        features: split.regular.features.filter(function(f) {
          return f.geometry && f.geometry.type === 'Point';
        })
      }

      let masterportalPointFeatures = {
        type: 'FeatureCollection',
        features: split.masterportal.features.filter(function(f) {
          return f.geometry && f.geometry.type === 'Point';
        })
      }

      pointFeatures.features.forEach(function(feature) {
        if (feature.properties && feature.properties.feature_icon_unicode) {
          feature.properties.feature_icon_unicode_processed = String.fromCharCode(parseInt(feature.properties.feature_icon_unicode, 16));
        }
      });

      const clusterColor = App.Utils.hexToRgba(App.Utils.getBrandColor(), 0.75);

      this.hasMasterportalPins = masterportalPointFeatures.features.length > 0;

      if (this.features && Object.keys(this.features).length > 0) {
        this.map.addSource('user-features-points', {
          type: 'geojson',
          data: pointFeatures,
          cluster: true,
          clusterMaxZoom: 17,
          clusterRadius: 50
        });

        this.map.addLayer({
          id: 'user-features-circles-clusters',
          type: 'circle',
          source: 'user-features-points',
          filter: ['has', 'point_count'],
          paint: {
            'circle-color': [ 'step', ['get', 'point_count'], clusterColor, 10, clusterColor, 30, clusterColor ],
            'circle-radius': [ 'step', ['get', 'point_count'], 18, 10, 22, 28, 25 ]
          }
        });

        this.map.addLayer({
          id: 'user-features-circles-cluster-count',
          type: 'symbol',
          source: 'user-features-points',
          filter: ['has', 'point_count'],
          layout: { 'text-field': '{point_count_abbreviated}', 'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'], 'text-size': 12 },
          paint: { 'text-color': '#ffffff' }
        });

        this.map.addLayer({
          id: 'user-features-circles',
          type: 'circle',
          source: 'user-features-points',
          filter: ['!', ['has', 'point_count']],
          paint: {
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 16, 16 ],
            'circle-color':  [ 'coalesce', ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor],
            'circle-opacity': 0.75
          }
        });

        this.map.addLayer({
          id: 'user-features-circles-icons',
          type: 'symbol',
          source: 'user-features-points',
          filter: ['all', ['!', ['has', 'point_count']], ['has', 'feature_icon_unicode_processed']],
          layout: {
            'text-field': ['get', 'feature_icon_unicode_processed'],
            'text-font': ['Font Awesome 5 Free Regular', 'Font Awesome 5 Free Solid', 'Font Awesome 5 Brands Regular'],
            'text-size': 14,
            'text-offset': [0, 0.2]
          },
          paint: { 'text-color': '#ffffff' }
        });

        this.map.on('click', 'user-features-circles-clusters', (e) => {
          const features = this.map.queryRenderedFeatures(e.point, {
            layers: ['user-features-circles-clusters']
          });
          const clusterId = features[0].properties.cluster_id;
          this.map.getSource('user-features-points').getClusterExpansionZoom(clusterId, (err, zoom) => {
            if (err) return;
            this.map.easeTo({
              center: features[0].geometry.coordinates,
              zoom: zoom + 1
            });
          });
        });

        this.map.addSource('user-features-shapes', {
          type: 'geojson',
          data: App.Map.formattedFeatures(this.features)
        });

        this.map.addLayer({
          id: 'user-features-lines',
          type: 'line',
          source: 'user-features-shapes',
          filter: ['==', '$type', 'LineString'],
          layout: { 'line-join': 'round', 'line-cap': 'round' },
          paint: { 'line-color': [ 'coalesce', ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor], 'line-width': 4 }
        });

        this.map.addLayer({
          id: 'user-features-polygons',
          type: 'fill',
          source: 'user-features-shapes',
          filter: ['==', '$type', 'Polygon'],
          layout: {},
          paint: { 'fill-color': [ 'coalesce', ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor], 'fill-opacity': 0.5 }
        });

        if (this.hasMasterportalPins) {
          this.addMasterportalPinsLayers(masterportalPointFeatures, clusterColor);
          this.addMasterportalPinsCheckbox();
        }

        if (this.process && App.MapPopup.excludedProcesses.indexOf(this.process) === -1) {
          const userFeaturesLayers = ['user-features-circles', 'user-features-lines', 'user-features-polygons'];
          const instance = this;
          userFeaturesLayers.forEach(function(layerId) {
            instance.map.on('mouseenter', layerId, () => {
              instance.map.getCanvas().style.cursor = 'pointer';
            });

            instance.map.on('mouseleave', layerId, () => {
              instance.map.getCanvas().style.cursor = '';
            });

            instance.map.on('click', layerId, instance.openMarkerPopup);
          })

          if (this.hasMasterportalPins) {
            ['masterportal-pins-circles', 'masterportal-pins-icons'].forEach(function(layerId) {
              instance.map.on('mouseenter', layerId, () => {
                instance.map.getCanvas().style.cursor = 'pointer';
              });

              instance.map.on('mouseleave', layerId, () => {
                instance.map.getCanvas().style.cursor = '';
              });

              instance.map.on('click', layerId, instance.openMarkerPopup);
            })
          }
        }
      }
    }

    addMasterportalPinsLayers(featureCollection, clusterColor) {
      this.map.addSource('masterportal-pins-points', {
        type: 'geojson',
        data: featureCollection,
        cluster: true,
        clusterMaxZoom: 17,
        clusterRadius: 50
      });

      this.map.addLayer({
        id: 'masterportal-pins-circles-clusters',
        type: 'circle',
        source: 'masterportal-pins-points',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': [ 'step', ['get', 'point_count'], clusterColor, 10, clusterColor, 30, clusterColor ],
          'circle-radius': [ 'step', ['get', 'point_count'], 18, 10, 22, 28, 25 ]
        }
      });

      this.map.addLayer({
        id: 'masterportal-pins-circles-cluster-count',
        type: 'symbol',
        source: 'masterportal-pins-points',
        filter: ['has', 'point_count'],
        layout: { 'text-field': '{point_count_abbreviated}', 'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'], 'text-size': 12 },
        paint: { 'text-color': '#ffffff' }
      });

      this.map.addLayer({
        id: 'masterportal-pins-circles',
        type: 'circle',
        source: 'masterportal-pins-points',
        filter: ['all', ['!', ['has', 'point_count']], ['!', ['has', 'feature_icon_id']]],
        paint: {
          'circle-radius': 16,
          'circle-color':  [ 'coalesce', ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor],
          'circle-opacity': 0.75
        }
      });

      this.map.on('click', 'masterportal-pins-circles-clusters', (e) => {
        const features = this.map.queryRenderedFeatures(e.point, {
          layers: ['masterportal-pins-circles-clusters']
        });
        const clusterId = features[0].properties.cluster_id;
        this.map.getSource('masterportal-pins-points').getClusterExpansionZoom(clusterId, (err, zoom) => {
          if (err) return;
          this.map.easeTo({
            center: features[0].geometry.coordinates,
            zoom: zoom + 1
          });
        });
      });

      this.addMasterportalPinIcons(featureCollection);
    }

    addMasterportalPinIcons(featureCollection) {
      const iconIdsByUrl = this.collectMasterportalIconIds(featureCollection);

      if (this.masterportalDefaultIconUrl && !iconIdsByUrl[this.masterportalDefaultIconUrl]) {
        iconIdsByUrl[this.masterportalDefaultIconUrl] = 'masterportal-pin-icon-default';
      }

      const iconUrls = Object.keys(iconIdsByUrl);

      if (iconUrls.length === 0) return;

      const loadState = {
        featureCollection: featureCollection,
        iconIdsByUrl: iconIdsByUrl,
        loadedIconsByUrl: {},
        pendingLoads: iconUrls.length
      };

      iconUrls.forEach((iconUrl) => {
        this.loadMasterportalIconImage(iconUrl, (error, image) => {
          this.handleMasterportalPinIconLoad(loadState, iconUrl, error, image);
        });
      });
    }

    loadMasterportalIconImage(iconUrl, callback) {
      const image = new Image();

      image.crossOrigin = 'anonymous';
      image.onload = function() { callback(null, image); };
      image.onerror = function() { callback(new Error('Masterportal icon load failed: ' + iconUrl)); };
      image.src = encodeURI(iconUrl);
    }

    collectMasterportalIconIds(featureCollection) {
      const iconIdsByUrl = {};

      featureCollection.features.forEach(function(feature) {
        const iconUrl = feature.properties && feature.properties.feature_icon_url;

        if (iconUrl && !iconIdsByUrl[iconUrl]) {
          iconIdsByUrl[iconUrl] = 'masterportal-pin-icon-' + Object.keys(iconIdsByUrl).length;
        }
      });

      return iconIdsByUrl;
    }

    handleMasterportalPinIconLoad(loadState, iconUrl, error, image) {
      if (!error && image) {
        const iconId = loadState.iconIdsByUrl[iconUrl];

        try {
          if (!this.map.hasImage(iconId)) {
            this.map.addImage(iconId, this.rasterizeMasterportalIcon(image), { pixelRatio: 2 });
          }

          loadState.loadedIconsByUrl[iconUrl] = iconId;
        } catch (rasterizationError) {
          console.warn('Masterportal icon rasterization failed', iconUrl, rasterizationError);
        }
      }

      loadState.pendingLoads -= 1;

      if (loadState.pendingLoads === 0) {
        this.applyMasterportalPinIcons(loadState.featureCollection, loadState.loadedIconsByUrl);
      }
    }

    rasterizeMasterportalIcon(image) {
      const size = 72;
      const canvas = document.createElement('canvas');
      canvas.width = size;
      canvas.height = size;

      const context = canvas.getContext('2d');
      const naturalWidth = image.naturalWidth || size;
      const naturalHeight = image.naturalHeight || size;
      const scale = Math.min(size / naturalWidth, size / naturalHeight);
      const drawWidth = naturalWidth * scale;
      const drawHeight = naturalHeight * scale;

      context.drawImage(image, (size - drawWidth) / 2, (size - drawHeight) / 2, drawWidth, drawHeight);

      return context.getImageData(0, 0, size, size);
    }

    applyMasterportalPinIcons(featureCollection, loadedIconsByUrl) {
      if (Object.keys(loadedIconsByUrl).length === 0) return;

      const source = this.map.getSource('masterportal-pins-points');

      if (!source) return;

      const defaultIconId = this.masterportalDefaultIconUrl ?
        loadedIconsByUrl[this.masterportalDefaultIconUrl] : null;

      featureCollection.features.forEach(function(feature) {
        if (!feature.properties) return;

        const iconId = loadedIconsByUrl[feature.properties.feature_icon_url] || defaultIconId;

        if (iconId) {
          feature.properties.feature_icon_id = iconId;
        }
      });

      source.setData(featureCollection);
      this.addMasterportalPinsIconsLayer();
    }

    addMasterportalPinsIconsLayer() {
      if (this.map.getLayer('masterportal-pins-icons')) return;

      const layout = {
        'icon-image': ['get', 'feature_icon_id'],
        'icon-allow-overlap': true
      };

      if (this.map.getLayoutProperty('masterportal-pins-circles', 'visibility') === 'none') {
        layout.visibility = 'none';
      }

      this.map.addLayer({
        id: 'masterportal-pins-icons',
        type: 'symbol',
        source: 'masterportal-pins-points',
        filter: ['all', ['!', ['has', 'point_count']], ['has', 'feature_icon_id']],
        layout: layout
      });
    }

    addMasterportalPinsCheckbox() {
      if (!this.layerControl) return;

      const instance = this;
      const layerIds = [
        'masterportal-pins-circles-clusters',
        'masterportal-pins-circles-cluster-count',
        'masterportal-pins-circles',
        'masterportal-pins-icons'
      ];

      const label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      const input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = true;

      const span = document.createElement('span');
      span.textContent = this.masterportalPinsLayerLabel;

      label.appendChild(input);
      label.appendChild(span);

      input.addEventListener('change', () => {
        layerIds.forEach((layerId) => {
          instance.toggleLayer(layerId, instance.map, input.checked);
        });
      });

      this.layerControl.dropdownList.appendChild(label);
    }

    openMarkerPopup(e) {
      if (this._popupOpen) return;
      this._popupOpen = true;

      if (!e.features || !e.features.length || !e.features[0]) {
        console.warn("No features found in popup event:", e);
        return;
      }

      const properties = e.features[0].properties;
      const resourceType = properties["resource_type"]

      // Show empty popup immediately
      var popup = new mapboxgl.Popup({
        offset: 20,
        closeButton: true,
        maxWidth: '250px'
      })
        .setLngLat(e.lngLat)
        .setHTML('<div class="map-popup-status-message">Laden...</div>')
        .addTo(this);

      var popupDataUrl = App.MapPopup.getPopupDataUrl(resourceType, properties)

      if (!popupDataUrl) return;

      $.ajax(popupDataUrl, {
        type: "GET",
        dataType: "json"
      })
        .then(function(data) {
          popup.setHTML(App.MapPopup.generatePopupContent(data, resourceType, properties));
        })
        .fail(function() {
          popup.setHTML('<div class="map-popup-status-message error">Failed to load data</div>');
        })
        .always(function() {
          this._popupOpen = false;
        }.bind(this));
    }

    addSwitchToSimpleSelectControl() {
      const instance = this;
      let button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-switch-to-simple-select-control-button';
      button.innerHTML = '<i class="fas fa-hand-spock"></i>';
      button.title = 'Auswahlmodus';

      this.element.querySelector('.mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_point').insertAdjacentElement('afterend', button);

      button.addEventListener('click', () => {
        if (button.classList.contains('active')) {
          toggleInactive();
        } else {
          toggleActive();
        }
      });

      instance.map.on('draw.modechange', function(e) {
        button.classList.remove('active');
      });

      function toggleActive() {
        button.classList.add('active')
        document.querySelectorAll('.mapbox-gl-draw_ctrl-draw-btn').forEach(function(btn) {
          btn.classList.remove('active');
        });
        instance.draw.changeMode('simple_select');
      }

      function toggleInactive() {
        button.classList.remove('active')
        document.querySelector('.mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_point').classList.add('active');
        instance.draw.changeMode('draw_point');
      }
    }

    setupEditingControls() {
      if (!this.editable)  return;

      const instance = this;

      instance.draw = new MapboxDraw({
        displayControlsDefault: false,
        controls: {
          point: true,
          line_string: instance.enableShapes,
          polygon: instance.enableShapes,
          trash: true
        },
        defaultMode: 'draw_point',
        userProperties: true,
        styles: instance.getDrawStyles()
      });

      instance.map.on('draw.update', function(e) {
        instance.updateFeaturesInput(instance.featuresInput, instance.editableLayers);
      });

      instance.map.addControl(this.draw, 'top-right');
      this.addSwitchToSimpleSelectControl();

      App.Map.formattedFeatures(instance.features).features.forEach(function(feature) {
        const added = instance.draw.add(feature);

        if (added && added.length > 0) {
          instance.editableLayers.push(added[0]);
        }
      });

      if (instance.editingProjektMap) {
        instance.map.addControl(new CenterMarkerControl(instance), 'top-right');
      }

      if (instance.editableLayersLimit && instance.editableLayersLimit > 1) {
        instance.addHintAboutEditableLayersLimit();
      }

      App.Map.setupEventListenersForMarkerStyleChanges(instance);
      instance.rearrangeEditingControls();
    }

    rearrangeEditingControls() {
      const pointControl = this.element.querySelector('.mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_point');
      const lineControl = this.element.querySelector('.mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_line');
      const polygonControl = this.element.querySelector('.mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_polygon');

      const drawingControlsGroup = pointControl.parentElement;

      if (pointControl && lineControl && polygonControl) {
        drawingControlsGroup.insertBefore(pointControl, drawingControlsGroup.firstChild);
        drawingControlsGroup.insertBefore(lineControl, pointControl.nextSibling);
      }

      const simpleSelectControl = this.element.querySelector('.mapbox-switch-to-simple-select-control-button');
      const trashControl = this.element.querySelector('.mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_trash');

      if (simpleSelectControl || trashControl) {
        const editControlsGroup = document.createElement('div');
        editControlsGroup.className = 'mapboxgl-ctrl mapboxgl-ctrl-group mapbox-edit-controls-group';
        drawingControlsGroup.insertAdjacentElement('afterend', editControlsGroup);

        if (simpleSelectControl) editControlsGroup.appendChild(simpleSelectControl);
        if (trashControl) editControlsGroup.appendChild(trashControl);
      }
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
            'fill-color': [ 'coalesce', ['get', 'user_feature_color'], ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor],
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
            'line-color': [ 'coalesce', ['get', 'user_feature_color'], ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor],
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
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 15, 12],
            'circle-color': [ 'case', ['==', ['get', 'active'], 'true'], '#fff', [ 'coalesce', ['get', 'user_feature_color'], ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor] ]
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
            'circle-radius': [ 'case', ['==', ['get', 'active'], 'true'], 12, 12],
            'circle-color': [ 'coalesce', ['get', 'user_feature_color'], ['get', 'feature_color'], ['get', 'color'], this.defaultFeatureColor],
          },
        },
        {
          'id': 'gl-draw-point-icon',
          'type': 'symbol',
          'filter': [ 'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'feature'],
            ['has', 'user_feature_icon_unicode']
          ],

          'layout': {
            'text-field': ['get', 'user_feature_icon_unicode'],
            'text-font': ['Font Awesome 5 Free Regular', 'Font Awesome 5 Free Solid', 'Font Awesome 5 Brands Regular'],
            'text-size': 10,
            'text-offset': [0, 0.2]
          },
          'paint': {
            'text-color': '#ffffff'
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
            'circle-color': [ 'case', ['has', 'user_feature_color'], ['get', 'user_feature_color'], this.defaultFeatureColor]
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

        if (instance.featureColor) {
          instance.draw.setFeatureProperty(newFeature.id, 'feature_color', instance.featureColor);
        }

        if (instance.featureIconName) {
          instance.draw.setFeatureProperty(newFeature.id, 'feature_icon_name', instance.featureIconName);
        }

        if (instance.featureIconUnicode) {
          instance.draw.setFeatureProperty(newFeature.id, 'feature_icon_unicode', String.fromCharCode(parseInt(instance.featureIconUnicode, 16)));
        }

        if (instance.featureCategoryName) {
          instance.draw.setFeatureProperty(newFeature.id, 'feature_category_name', instance.featureCategoryName);
        }

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

    toggleControlVisibility() {
      const topLeftControls = this.element.querySelector('.mapboxgl-ctrl-top-left');
      const layerControl = this.element.querySelector('.mapbox-layer-control');
      const instructionOverlay = this.element.querySelector('.mapbox-instruction-overlay');

      if ( this.element.offsetWidth < 700 ) {
        [topLeftControls, layerControl, instructionOverlay].forEach(control => {
          if (control) control.style.display = 'none';
        });
      } else {
        [topLeftControls, layerControl, instructionOverlay].forEach(control => {
          if (control) control.style.display = '';
        });
      }
    }

    setupEventListenersForUpdatingMapCenter() {
      if (!this.editable) return;

      const selectElement = document.querySelector('.js-update-map-center');
      if (!selectElement) return;

      selectElement.addEventListener('change', (event) => {
        const selectedOption = event.target.selectedOptions[0];
        const latitude = parseFloat(
          selectedOption.dataset.latitude ||
          event.target.dataset.defaultLatitude ||
          this.mapCenterLatitude
        );
        const longitude = parseFloat(
          selectedOption.dataset.longitude ||
          event.target.dataset.defaultLongitude ||
          this.mapCenterLongitude
        );

        if (!isNaN(latitude) && !isNaN(longitude)) {
          this.map.setCenter([longitude, latitude]);
          this.map.setZoom(this.map.getZoom());
        }
      });
    }

    moveOrPlaceMarker(lat, lng) {
      if (this.currentMarker) {
        this.currentMarker.remove();
      }

      this.currentMarker = new mapboxgl.Marker({ color: App.Utils.getBrandColor() })
      this.currentMarker.setLngLat([lng, lat]).addTo(this.map);

      this.latitudeInput.value = lat.toFixed(6);
      this.longitudeInput.value = lng.toFixed(6);
      this.zoomInput.value = this.map.getZoom();
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

  class ExpandControl {
    constructor(mapboxMapInstance) {
      this.mapboxMapInstance = mapboxMapInstance;
      this.mapContainer = mapboxMapInstance.element;
    }

    onAdd(map) {
      this._map = map;
      this._container = document.createElement('div');
      this._container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group';

      let button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-expand-control-button';
      button.innerHTML = '<i class="fas fa-expand"></i>';
      button.title = 'Vollbild-Modus';

      this._container.appendChild(button);

      button.addEventListener('click', () => {
        if (this.mapContainer.classList.contains('expanded')) {
          this.mapContainer.classList.remove('expanded');
          button.innerHTML = '<i class="fas fa-expand"></i>';
          map.resize();
          this.mapboxMapInstance.toggleControlVisibility();
        } else {
          this.mapContainer.classList.add('expanded');
          button.innerHTML = '<i class="fas fa-compress"></i>';
          map.resize();
          this.mapboxMapInstance.toggleControlVisibility();
        }
      });

      return this._container;
    }

    onRemove() {
      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
    }
  }

  class ResetViewControl {
    constructor(mapboxMapInstance) {
      this.mapboxMapInstance = mapboxMapInstance;
    }

    onAdd(map) {
      this._map = map;
      this._container = document.createElement('div');
      this._container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group';

      let button = document.createElement('button');
      button.type = 'button';
      button.innerHTML = '<i class="fas fa-home"></i>';
      button.title = 'Ansicht zurücksetzen';

      this._container.appendChild(button);

      button.addEventListener('click', () => {
        map.flyTo({
          center: [this.mapboxMapInstance.mapCenterLongitude, this.mapboxMapInstance.mapCenterLatitude],
          zoom: this.mapboxMapInstance.zoom,
          pitch: this.mapboxMapInstance.initialPitch,
          bearing: 0
        });
      });

      return this._container;
    }

    onRemove() {
      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
    }
  }

  class CenterMarkerControl {
    constructor(mapboxMapInstance) {
      this.mapboxMapInstance = mapboxMapInstance;
      this.mapContainer = mapboxMapInstance.element;
      this.active = false;
      this.mapboxMapInstance.currentMarker = new mapboxgl.Marker({ color: App.Utils.getBrandColor() })
        .setLngLat([this.mapboxMapInstance.mapCenterLongitude, this.mapboxMapInstance.mapCenterLatitude])
        .addTo(this.mapboxMapInstance.map);
    }

    onAdd(map) {
      this._map = map;
      this._container = document.createElement('div');
      this._container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group';

      let button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-center-marker-control-button';
      button.innerHTML = '<i class="fas fa-crosshairs"></i>';
      button.title = 'Zentrum markieren';

      this._container.appendChild(button);

      this._container.addEventListener('click', () => {
        if (this.active) {
          console.log('Center marker mode deactivated');
          this.deactivateCenterMarkerMode();
        } else {
          console.log('Center marker mode activated');
          this.activateCenterMarkerMode();
        }
      });

      return this._container;
    }

    onRemove() {
      this.deactivateCenterMarkerMode();
      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
    }

    activateCenterMarkerMode() {
      this.active = true;
      this._container.style.backgroundColor = '#f2f2f2';
      this.mapboxMapInstance.draw.changeMode('simple_select')

      const instance = this;

      this.clickHandler = function(e) {
        instance.mapboxMapInstance.moveOrPlaceMarker(e.lngLat.lat, e.lngLat.lng);
      }

      this._map.on('click', this.clickHandler);
    }

    deactivateCenterMarkerMode() {
      this.active = false;
      this._container.style.backgroundColor = '';

      if (this.clickHandler) {
        this.mapboxMapInstance.map.off('click', this.clickHandler);
        this.clickHandler = null;
      }
    }
  }

  window.App.MapboxMapController = MapboxMapController;
}).call(this);

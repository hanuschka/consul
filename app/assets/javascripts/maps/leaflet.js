(function() {
  "use strict";

  class LeafletMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();
      this.bindEventListeners();

      this.createMap();
      this.setupExpandControl();
      this.addResetViewControl();
      this.setupLayers();
      this.setupPlugins();
      this.renderFeatures();
      this.setupEditingControls();
      this.setupEventListenersForUpdatingFormInputs();
      this.toggleControlVisibility();
      this.setupEventListenersForUpdatingMapCenter();

      this.placeCenterMarker = this.placeCenterMarker.bind(this)

      if (!this.editable) {
        App.MapKeyboardFocus.neutralize(this.element);
      }
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
      this.masterportalImageIcons = {};
      this.masterportalPinsClusterGroup = null;
      this.hasMasterportalPins = false;
      this.layerControl = null;

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
        maxZoom: App.MapZoom.MAX,
        zoomControl: false,
        keyboard: !!this.editable
      }).setView(this.mapCenterLatLng, this.zoom);

      const zoomControl = L.control.zoom({
        zoomInTitle: 'Hineinzoomen',
        zoomOutTitle: 'Herauszoomen'
      });

      this.map.addControl(zoomControl);

      this.setupEscKeyHandler();

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

    setupEscKeyHandler() {
      const map = this.map;

      $(this.element).on('keydown', function(event) {
        if (event.which === 27) {
          map.closePopup();
        }
      });
    }

    whenIdle() {
      const instance = this;

      return new Promise((resolve) => {
        if (!instance.map) {
          resolve();
          return;
        }

        instance.map.whenReady(() => {
          const tileLayers = [];
          instance.map.eachLayer((layer) => {
            if (layer instanceof L.TileLayer) {
              tileLayers.push(layer);
            }
          });

          if (tileLayers.length === 0) {
            resolve();
            return;
          }

          let pending = tileLayers.length;
          tileLayers.forEach((layer) => {
            if (layer._loading === false) {
              pending -= 1;
              if (pending === 0) resolve();
              return;
            }

            layer.once('load', () => {
              pending -= 1;
              if (pending === 0) resolve();
            });
          });
        });
      });
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

    // Public Interface method for assistant map update and external use
    // DO NOT DELETE
    setMarkerTo(lat, lng, shouldScroll) {
      this.map.panTo(new L.LatLng(lat, lng));

      if (this.editingProjektMap) {
        this.placeCenterMarker([lat, lng])
      } else {
        const marker = L.marker([lat, lng], {
          icon: App.Utils.getLeafletMarkerHTML(this.defaultFeatureColor)
        });
        marker.addTo(this.map);
        this.map.fire('pm:create', { layer: marker, shape: 'Marker' });
      }

      if (shouldScroll) {
        this.map.getContainer().scrollIntoView({
          block: "center", inline: "nearest"
        })
      }
    }

    setupExpandControl() {
      const instance = this;

      L.Control.Expand = L.Control.extend({
        onAdd: function() {
          let container = document.createElement('div');
          container.className = 'control-container';

          let button = document.createElement('button');
          button.type = 'button';
          button.className = 'control-button js-map-expand-toggle';
          button.innerHTML = '<i class="fas fa-expand"></i>';
          button.title = 'Vollbild-Modus';

          container.appendChild(button);

          instance.expandButton = button;

          L.DomEvent.disableClickPropagation(container);

          container.addEventListener('click', (e) => {
            L.DomEvent.stopPropagation(e);

            instance.toggleExpand();
          });

          return container;
        },

        onRemove() {}
      })

      const expandControl = new L.Control.Expand({ position: 'topright' })
      this.map.addControl(expandControl);

      App.Map.bindEscToCollapseExpanded();
    }

    toggleExpand() {
      if (this.element.classList.contains('expanded')) {
        this.collapseMap();
      } else {
        this.expandMap();
      }
    }

    expandMap() {
      this.element.classList.add('expanded');
      this.updateExpandButton(true);
      this.map.invalidateSize();
      this.toggleControlVisibility();
    }

    collapseMap() {
      if (!this.element.classList.contains('expanded')) return;

      this.element.classList.remove('expanded');
      this.updateExpandButton(false);
      this.map.invalidateSize();
      this.toggleControlVisibility();
    }

    updateExpandButton(expanded) {
      if (!this.expandButton) return;

      const iconClass = expanded ? 'fa-compress' : 'fa-expand';
      this.expandButton.innerHTML = `<i class="fas ${iconClass}"></i>`;
    }

    addResetViewControl() {
      const instance = this;

      L.Control.ResetView = L.Control.extend({
        onAdd: function() {
          let container = document.createElement('div');
          container.className = 'control-container';

          let button = document.createElement('button');
          button.type = 'button';
          button.className = 'control-button';
          button.innerHTML = '<i class="fas fa-home"></i>';
          button.title = 'Ansicht zurücksetzen';

          container.appendChild(button);

          L.DomEvent.disableClickPropagation(container);

          container.addEventListener('click', function(e) {
            L.DomEvent.stopPropagation(e);
            instance.map.setView(instance.mapCenterLatLng, instance.zoom, { animate: true });
          });

          return container;
        },

        onRemove() {}
      });

      const resetControl = new L.Control.ResetView({ position: 'topright' });
      this.map.addControl(resetControl);
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

      // Set up the toggleable Masterportal pins overlay (only when pins exist)
      this.setupMasterportalPinsOverlay();

      // Add layer control if needed
      this.addLayerControl();
    }

    setupMasterportalPinsOverlay() {
      if (this.editable) return;
      if (this.masterportalPinsClusterGroup) return;

      const split = App.Map.splitMasterportalFeatures(this.features);
      if (split.masterportal.features.length === 0) return;

      this.hasMasterportalPins = true;
      this.masterportalPinsClusterGroup = L.markerClusterGroup({ removeOutsideVisibleBounds: false });
      this.masterportalPinsClusterGroup.options.show_by_default = true;
      this.masterportalPinsClusterGroup.addTo(this.map);
      this.overlayLayers[this.masterportalPinsLayerLabel] = this.masterportalPinsClusterGroup;

      if (this.layerControl) {
        this.layerControl.addOverlay(this.masterportalPinsClusterGroup, this.masterportalPinsLayerLabel);
      }
    }

    createLayer(item) {
      const zoomLimits = App.MapZoom;
      let layer;

      if (item.protocol === 'wms') {
        layer = L.tileLayer.wms(item.provider, {
          attribution: item.attribution,
          layers: item.layer_names,
          format: (item.transparent ? 'image/png' : 'image/jpeg'),
          transparent: (item.transparent),
          show_by_default: (item.show_by_default),
          opacity: (item.opacity ? item.opacity : 1),
          maxZoom: zoomLimits.MAX
        });
      } else if (item.protocol === 'geojson') {
        layer = this.createGeoJsonOverlay(item);
      } else {
        layer = L.tileLayer(item.provider, {
          attribution: item.attribution,
          maxZoom: zoomLimits.MAX,
          maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
        });
      }

      if (item.base) {
        this.baseLayers[item.name] = layer;
      } else {
        this.overlayLayers[item.name] = layer;
      }
    }

    createGeoJsonOverlay(item) {
      const group = L.layerGroup();
      group.options.show_by_default = item.show_by_default;
      group._geojsonLoaded = false;

      // Lazy-load on first display: default-on layers fetch immediately (setupLayers
      // adds them), toggled-off layers fetch only when first enabled.
      group.on("add", () => {
        if (!group._geojsonLoaded) {
          group._geojsonLoaded = true;
          this.loadGeoJsonInto(group, item);
        }
      });

      return group;
    }

    loadGeoJsonInto(group, item) {
      if (!item.data_url) return;

      fetch(item.data_url)
        .then((response) => response.json())
        .then((data) => {
          const cfg = item.config || {};
          // Overlays are non-interactive: an interactive Leaflet canvas layer blocks
          // map dragging everywhere except directly on a feature. pmIgnore keeps
          // Geoman from treating the overlay as an editable shape.
          const gj = L.geoJSON(data, {
            renderer: L.canvas({ padding: 0.5 }),
            interactive: false,
            pmIgnore: true,
            style: (feature) => this.geoJsonStyle(feature, cfg)
          });

          gj.addTo(group);

          if (cfg.choropleth && cfg.choropleth.enabled) {
            this.addChoroplethLegend(cfg);
          }
        })
        .catch((err) => console.error("Failed to load GeoJSON layer", item.name, err));
    }

    geoJsonStyle(feature, cfg) {
      const style = cfg.style || {};

      let fillColor = style.fillColor || "#3366CC";
      const fillOpacity = App.Map.numberOrDefault(style.fillOpacity, 0.3);
      const color = style.color || "#1A3C8C";
      const weight = App.Map.numberOrDefault(style.weight, 1);

      if (cfg.choropleth && cfg.choropleth.enabled) {
        fillColor = this.choroplethColor(feature.properties[cfg.choropleth.property], cfg.choropleth);
      }

      return { fillColor: fillColor, fillOpacity: fillOpacity, color: color, weight: weight };
    }

    choroplethColor(value, ch) {
      const v = parseFloat(value);
      if (isNaN(v)) return ch.no_data_color || "#cccccc";

      const breaks = ch.breaks || [];
      const colors = ch.colors || [];

      let i = 0;
      while (i < breaks.length && v >= parseFloat(breaks[i])) i++;

      return colors[i] || colors[colors.length - 1] || "#cccccc";
    }

    addChoroplethLegend(cfg) {
      const ch = cfg.choropleth || {};
      const breaks = ch.breaks || [];
      const colors = ch.colors || [];

      const legend = L.control({ position: "bottomright" });

      legend.onAdd = () => {
        const container = L.DomUtil.create("div", "leaflet-control-attribution map-choropleth-legend");
        const rows = [];

        if (ch.legend_title) {
          rows.push('<div class="map-choropleth-legend__title"><strong>' + App.MapPopup.escapeHtml(ch.legend_title) + "</strong></div>");
        }

        for (let i = 0; i < colors.length; i++) {
          let label;
          if (i === 0) {
            label = "< " + App.MapPopup.escapeHtml(breaks[0]);
          } else if (i === colors.length - 1) {
            label = "≥ " + App.MapPopup.escapeHtml(breaks[breaks.length - 1]);
          } else {
            label = App.MapPopup.escapeHtml(breaks[i - 1]) + " – " + App.MapPopup.escapeHtml(breaks[i]);
          }

          const swatch = '<span class="map-choropleth-legend__swatch" style="display:inline-block;width:14px;height:14px;margin-right:6px;background:' + App.MapPopup.escapeHtml(colors[i]) + '"></span>';
          rows.push('<div class="map-choropleth-legend__row">' + swatch + label + "</div>");
        }

        container.innerHTML = rows.join("");
        return container;
      };

      legend.addTo(this.map);
      this._geojsonLegends = this._geojsonLegends || [];
      this._geojsonLegends.push(legend);
    }

    ensureBaseLayerExistence() {
      if (Object.keys(this.baseLayers).length === 0) {
        const defaultLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
          attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors',
          maxZoom: App.MapZoom.MAX,
          maxNativeZoom: App.MapZoom.MAX_NATIVE_TILE
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

      this.layerControl = layerControl;
    }

    addAdminFeaturesAsLayer() {
      const adminFeaturesLayer = L.geoJSON(this.adminFeatures, {
        pmIgnore: true,
        pointToLayer: function(feature, latlng) {
          return L.marker(latlng, {
            pmIgnore: true,
            icon: App.Utils.getLeafletMarkerHTML('#008000', null, 'Verwaltungseintrag')
          });
        },
        style: {
          color: '#008000',
          weight: 2,
          fillOpacity: 0.2
        },
        onEachFeature: (feature, layer) => {
          layer.bindTooltip('Vom System vorgegeben – nicht verschiebbar', {
            direction: 'top',
            sticky: true
          });
          layer.bindPopup('<div class="map-popup-status-message">Alle markierten Flächen und Pins in grün sind vom System vorgegeben</div>');
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
      const adminShapeExplainerText = 'Alle markierten Flächen und Pins in grün sind vom System vorgegeben';
      const adminShapeExplainer = L.control({
        position: 'bottomleft'
      });

      adminShapeExplainer.onAdd = () => {
        const container = L.DomUtil.create('div', 'my-attribution');
        container.innerHTML = adminShapeExplainerText;
        container.className += ' leaflet-control-attribution';
        container.style.color = '#008000';
        return container;
      };

      adminShapeExplainer.addTo(this.map);
    }

    setupPlugins() {
      var locateControl = L.control.locate({
        icon: 'fa fa-map-marker',
        strings: {
          title: 'Meine Position anzeigen'
        }
      }).addTo(this.map);

      var locateButton = locateControl.getContainer().querySelector('a');
      if (locateButton) {
        locateButton.setAttribute('aria-label', 'Meine Position anzeigen');
        locateButton.querySelector('.fa').setAttribute('aria-hidden', 'true');
      }

      const searchControl = new GeoSearch.GeoSearchControl({
        provider: new GeoSearch.OpenStreetMapProvider(),
        style: 'bar',
        showMarker: false,
        searchLabel: 'Nach Adresse suchen',
        notFoundMessage: 'Entschuldigung! Die Adresse wurde nicht gefunden.',
        clearSearchLabel: 'Suche zurücksetzen'
      });
      this.map.addControl(searchControl);

      const searchInput = this.element.querySelector('.leaflet-control-geosearch input[type="text"]');
      if (searchInput) {
        searchInput.setAttribute('title', 'Nach Adresse suchen');
        searchInput.setAttribute('aria-label', 'Nach Adresse suchen');
      }

      this.clusterGroup = L.markerClusterGroup({ removeOutsideVisibleBounds: false });

      // Leaflet.Deflate plugin
      this.deflateFeatures = L.deflate({
        minSize: 30,
        markerLayer: this.clusterGroup,
        markerOptions: (shape) => {
          var title = shape.feature.properties.feature_category_name || shape.feature.properties.title || "Kartenmarkierung";

          return {
            icon: App.Utils.getLeafletMarkerHTML(shape.feature.properties.color || this.defaultFeatureColor, shape.feature.properties.feature_icon_name, title),
          }
        }

      });

      this.deflateFeatures.addTo(this.map);
    }

    renderFeatures() {
      if (this.features && Object.keys(this.features).length > 0) {
        this.setupMasterportalPinsOverlay();

        const split = App.Map.splitMasterportalFeatures(this.features);

        this.renderFeatureCollection(split.regular, this.clusterGroup);

        if (this.masterportalPinsClusterGroup) {
          this.renderFeatureCollection(split.masterportal, this.masterportalPinsClusterGroup);
        }
      }
      if (this.editingProjektMap) {
        this.placeCenterMarker(this.mapCenterLatLng);
      }
    }

    createMasterportalImageIcon(iconUrl) {
      if (!this.masterportalImageIcons[iconUrl]) {
        this.masterportalImageIcons[iconUrl] = L.icon({
          iconUrl: encodeURI(iconUrl),
          iconSize: [36, 36],
          iconAnchor: [18, 18]
        });
      }

      return this.masterportalImageIcons[iconUrl];
    }

    createUserImageIcon(iconUrl) {
      var imgHtml = "<img src='" + encodeURI(iconUrl) + "' alt='' referrerpolicy='no-referrer'>";
      var shape = "<svg class='map-user-pin--shape' viewBox='0 0 40 52' aria-hidden='true'>" +
        "<path d='M20 0C9 0 0 9 0 20c0 11 20 32 20 32s20-21 20-32C40 9 31 0 20 0z'/></svg>";
      var head = "<span class='map-user-pin--icon'>" + imgHtml + "</span>";

      return L.divIcon({
        className: "map-user-pin",
        html: "<span class='map-user-pin--teardrop'>" + shape + head + "</span>",
        iconSize: [46, 60],
        iconAnchor: [23, 60],
        popupAnchor: [0, -54]
      });
    }

    renderFeatureCollection(featureCollection, pointCluster) {
      if (!featureCollection || featureCollection.features.length === 0) return;
      const self = this;

      L.geoJSON(featureCollection, {
        pointToLayer: function(feature, latlng) {
          var markerTitle = feature.properties.feature_category_name || feature.properties.title || "Kartenmarkierung";
          var icon;

          if (feature.properties.feature_icon_url) {
            if (self.hasMasterportalPins && feature.properties.resource_type !== "masterportal_pin") {
              icon = self.createUserImageIcon(feature.properties.feature_icon_url);
            } else {
              icon = self.createMasterportalImageIcon(feature.properties.feature_icon_url);
            }
          } else if (feature.properties.resource_type === "masterportal_pin") {
            icon = App.Utils.getMasterportalDotMarker(feature.properties.feature_color || self.defaultFeatureColor);
          } else {
            icon = App.Utils.getLeafletMarkerHTML(feature.properties.feature_color || feature.properties.color || self.defaultFeatureColor, feature.properties.feature_icon_name, markerTitle);
          }

          return L.marker(latlng, { icon: icon });
        },
        style: function (feature) {
          return {
            weight: 2,
            color: feature.properties.feature_color || feature.properties.color || self.defaultFeatureColor
          };
        },
        onEachFeature: function (feature, layer) {
          if (self.editable) {
            self.setupEventListenersForEditableFeature(self.map, layer)
            self.editableLayers.push(layer);

            layer.addTo(self.map);

            layer.on('pm:edit', function(e) {
              self.updateFeaturesInput(self.featuresInput, self.editableLayers);
            });
          } else {
            if (feature.geometry.type === 'Point') {
              pointCluster.addLayer(layer);
            } else {
              self.deflateFeatures.addLayer(layer);
            }

            if (self.process && App.MapPopup.excludedProcesses.indexOf(self.process) === -1) {
              layer.options.resource_type = feature.properties.resource_type || null;
              layer.options.id = feature.properties.id || null;
              layer.options.feature_color = feature.properties.feature_color || self.defaultFeatureColor;
              layer.options.feature_icon_name = feature.properties.feature_icon_name || 'circle';
              layer.options.feature_category_name = feature.properties.feature_category_name || null;
              layer.options.has_masterportal_context = self.hasMasterportalPins;

              layer.on("click", self.openMarkerPopup);
            }
          }
        }
      });
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
          const popupOptions = { autoPanPadding: [0, 80], minWidth: 200, offset: L.point(0, -30) };

          if (resourceType === "masterportal_pin") {
            popupOptions.className = "masterportal-popup-wrapper";
            popupOptions.minWidth = 260;
            popupOptions.maxWidth = 360;
            popupOptions.offset = L.point(0, -20);
          }

          e.target.bindPopup(
            App.MapPopup.generatePopupContent(data, resourceType, properties, e.target.options.has_masterportal_context),
            popupOptions
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
          onClick: () => {
            const isToggled = !this.map.pm.Toolbar.buttons.centerMarker.toggled();

            if (isToggled) {
              this.map.on('click', function(e) {
                self.placeCenterMarker(e.latlng);
              });
            } else {
              this.map.off('click');
            }
          }
        })
      }

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

    placeCenterMarker(centerLatLng) {
      if (this.centerMarker) {
        this.map.removeLayer(this.centerMarker);
      }

      const centerMarker = L.marker(centerLatLng, {
        draggable: true,
        icon: App.Utils.getLeafletMarkerHTML()
      })

      this.centerMarker = centerMarker;
      this.map.addLayer(centerMarker);
      this.latitudeInput.value = centerMarker.getLatLng().lat.toFixed(6);
      this.longitudeInput.value = centerMarker.getLatLng().lng.toFixed(6);
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

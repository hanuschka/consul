(function() {
  "use strict";

  class LeafletMapController {
    constructor(element) {
      this.element = element;

      this.initializeProperties();
      this.bindEventListeners();

      this.createMap();
      this.setupBasicPlugins();
      this.setupLayers();

      this.renderAdminShapes();
      this.renderProcessCoordinates();
      this.renderAdminShapeInstructionNote();

      this.setupEditingControls();
    }

    initializeProperties() {
      const $element = $(this.element);

      // Map configuration
      this.mapCenterLatitude = $element.data("map-center-latitude");
      this.mapCenterLongitude = $element.data("map-center-longitude");
      this.mapCenterLatLng = new L.LatLng(this.mapCenterLatitude, this.mapCenterLongitude);
      this.zoom = $element.data("map-zoom");

      // Layer configuration
      this.layersData = $element.data('map-layers');
      this.baseLayers = {};
      this.overlayLayers = {};

      // Admin configuration
      this.adminShape = $element.data("admin-shape");
      this.showAdminShape = $element.data("show-admin-shape");
      this.adminEditor = $element.data("admin-editor");
      this.colors = $element.data("colors");
      this.adminShapesColor = this.colors.admin_shapes;
      this.projektCenterMarkerColor = this.colors.projekt_center_marker;

      // Process configuration
      this.process = $element.data("parent-class");
      this.processCoordinates = $element.data("process-coordinates");
      console.log("this.processCoordinates", this.processCoordinates)

      // Form selectors
      this.latitudeInputSelector = $element.data("latitude-input-selector");
      this.longitudeInputSelector = $element.data("longitude-input-selector");
      this.zoomInputSelector = $element.data("zoom-input-selector");
      this.shapeInputSelector = $element.data("shape-input-selector");
      this.showAdminShapeInputSelector = $element.data("show-admin-shape-input-selector");

      // Editing configuration
      this.editable = $element.data("editable");
      this.enableGeomanControls = $element.data("enable-geoman-controls");
      this.dontOpenMarkerPopup = $element.data('dont-open-marker-popup');
      this.setAdminCenterWithMarker = $element.data('set-admin-center-with-marker');

      // State
      this.centerMarker = null;
      this.markersGroup = L.markerClusterGroup({ removeOutsideVisibleBounds: false });
      this.isRemovingShapes = false;

      // Marker styling for Point of Interest etc
      this.userMarkerCategoryIcon = null;
      this.userMarkerCategoryColor = null;

      this.setupMarkerCategorySelection();
    }

    bindEventListeners() {
      this.moveOrPlaceCenterMarker = this.moveOrPlaceCenterMarker.bind(this);
      this.placeMultiMarker = this.placeMultiMarker.bind(this);
      this.openMarkerPopup = this.openMarkerPopup.bind(this);
    }

    setupMarkerCategorySelection() {
      const $categorySelect = $(".js-map-update-pin-style");

      $categorySelect.on("change", (e) => {
        this.updateMarkerStyleFromCategorySelect(e.target);
      });

      if ($categorySelect.length) {
        this.updateMarkerStyleFromCategorySelect($categorySelect.get(0));
      }
    }

    createMap() {
      this.map = L.map(this.element.id, {
        gestureHandling: true,
        maxZoom: 18,
        zoomControl: false
      }).setView(this.mapCenterLatLng, this.zoom);


      // Add zoom control
      const zoomControl = L.control.zoom({
        zoomInTitle: 'Hineinzoomen',
        zoomOutTitle: 'Herauszoomen'
      });
      this.map.addControl(zoomControl);

      // Add fullscreen modal control if applicable
      if (!$(this.element).data('modal-map') && !this.editable) {
        const fullscreenControl = new L.Control.FullscreenModal({ element: this.element });
        this.map.addControl(fullscreenControl);
      }

      this.map.on("moveend", this.handleMapMoveEnd.bind(this));

      // this.element.classList.add("js-map-initialized")
      this.element.setAttribute("data-map-initialized", "true");
    }

    handleMapMoveEnd() {
      if (this.adminEditor && !this.setAdminCenterWithMarker) {
        $(this.latitudeInputSelector).val(this.map.getCenter().lat);
        $(this.longitudeInputSelector).val(this.map.getCenter().lng);
        $(this.zoomInputSelector).val(this.map.getZoom());
      }
    }

    setupBasicPlugins() {
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

    setupLayers() {
      // Create layers
      if (typeof this.layersData !== "undefined") {
        this.layersData.forEach((item) => this.createLayer(item));
      }

      // Ensure at least one base layer exists
      this.ensureBaseLayerExistence();
      this.baseLayers[Object.keys(this.baseLayers)[0]].addTo(this.map);

      // Add overlay layers that should be visible by default
      if (Object.keys(this.overlayLayers).length > 0) {
        for (let key of Object.keys(this.overlayLayers)) {
          if (this.overlayLayers[key].options.show_by_default === true) {
            this.overlayLayers[key].addTo(this.map);
          }
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
      }

      // Add admin shapes toggle if needed
      if (layerControl && this.showAdminShape) {
        this.addAdminShapesToggleToLayerControl(layerControl);
      }
    }

    addAdminShapesToggleToLayerControl(layerControl) {
      setTimeout(() => {
        const layerControlContainer = layerControl.getContainer();
        if (layerControlContainer) {
          const form = layerControlContainer.querySelector('.leaflet-control-layers-list');
          if (form) {
            const adminLabel = document.createElement('label');

            const adminCheckbox = document.createElement('input');
            adminCheckbox.type = 'checkbox';
            adminCheckbox.checked = true;
            adminCheckbox.className = 'admin-shapes-toggle';
            adminCheckbox.style.marginRight = '5px';

            const adminText = document.createElement('span');
            adminText.textContent = 'Verwaltungseinträge';

            adminLabel.appendChild(adminCheckbox);
            adminLabel.appendChild(adminText);
            form.insertBefore(adminLabel, form.firstChild);

            adminCheckbox.addEventListener('change', () => {
              this.toggleAdminShapes(adminCheckbox.checked);
            });
          }
        }
      }, 100);
    }

    toggleAdminShapes(visible) {
      this.map.eachLayer((layer) => {
        // Check for admin shapes
        if (layer.pm && layer.pm.options && layer.pm.options.adminShape) {
          if (visible) {
            if (layer.setStyle) {
              layer.setStyle({ opacity: 1, fillOpacity: layer.options.fillOpacity || 0.2 });
            }
            if (layer.setOpacity) {
              layer.setOpacity(1);
            }
          } else {
            if (layer.setStyle) {
              layer.setStyle({ opacity: 0, fillOpacity: 0 });
            }
            if (layer.setOpacity) {
              layer.setOpacity(0);
            }
          }
        }

        // Handle admin markers
        if (layer.options && layer.options.adminMarker) {
          const element = layer.getElement ? layer.getElement() : null;
          if (element) {
            element.style.display = visible ? 'block' : 'none';
          }
        }
      });
    }

    // Marker creation and styling methods
    getMarkerIcon(color, iconClass) {
      console.log("getMarkerIcon", color);
      return L.divIcon({
        className: "map-marker",
        iconSize: [30, 30],
        iconAnchor: [15, 40],
        html: this.getMarkerIconHTML(color, iconClass)
      });
    }

    getMarkerIconHTML(color, iconClass) {
      console.log("getMarkerIconHTML", color);

      if (!iconClass || iconClass.length === 0) {
        iconClass = 'circle';
      }

      if (color) {
        return `<div class="map-icon icon-${iconClass}" style="background-color: ${color}"></div>`;
      } else {
        return `<div class="map-icon icon-${iconClass}"></div>`;
      }
    }

    updateMarkerWithCategoryStyle() {
      if (this.centerMarker && this.userMarkerCategoryIcon && this.userMarkerCategoryColor) {
        console.log("perform updateMarkerWithCategoryStyle");
        this.centerMarker.setIcon(this.getMarkerIcon(this.userMarkerCategoryColor, this.userMarkerCategoryIcon));
      }
    }

    updateMarkerStyleFromCategorySelect(element) {
      const selectedOption = element.options[element.selectedIndex];
      this.userMarkerCategoryIcon = selectedOption.dataset.icon;
      this.userMarkerCategoryColor = selectedOption.dataset.color;
      this.updateMarkerWithCategoryStyle();
    }

    getProcessId(shape) {
      let id;

      if (this.process === "proposals") {
        id = shape.feature.proposal_id;
      } else if (this.process === "deficiency-reports") {
        id = shape.feature.deficiency_report_id;
      } else if (this.process === "projekts") {
        id = shape.feature.projekt_id;
      } else if (this.process === "budgets") {
        id = shape.feature.investment_id;
      }

      return id;
    }

    createMarker(latitude, longitude, color, iconClass, center_marker = false) {
      // console.log("createMarker", latitude, longitude, color, iconClass);
      const markerLatLng = new L.LatLng(latitude, longitude);

      if (this.userMarkerCategoryIcon) {
        iconClass = this.userMarkerCategoryIcon;
      }

      if (this.userMarkerCategoryColor) {
        color = this.userMarkerCategoryColor;
      }

      const marker = L.marker(markerLatLng, {
        icon: this.getMarkerIcon(color, iconClass),
        draggable: this.editable,
        center_marker
      });

      if (this.editable) {
        marker.on("dragend", () => this.updateFormShapeFields());
        marker.addTo(this.map);
      } else {
        this.markersGroup.addLayer(marker);
      }

      return marker;
    }

    // Event handlers
    moveOrPlaceCenterMarker(e) {
      // Only handle single user markers: not adminEditor OR adminEditor with setAdminCenterWithMarker
      if (this.adminEditor && !this.setAdminCenterWithMarker) return;

      if (this.centerMarker) {
        this.centerMarker.setLatLng(e.latlng);
        this.updateMarkerWithCategoryStyle();
      } else {
        let markerColor = null;

        if (this.process === "projekts") {
          markerColor = this.projektCenterMarkerColor;
        }
        this.centerMarker = this.createMarker(e.latlng.lat, e.latlng.lng, markerColor, null, true);
      }

      this.updateCenterMarkerFormFields();
    }

    placeMultiMarker(e) {
      if (this.adminEditor) {
        // In admin mode, always create new markers for multiple placement
        const newMarker = this.createMarker(e.latlng.lat, e.latlng.lng, this.adminShapesColor);
        this.updateFormShapeFields();
      }
    }

    openMarkerPopup(e) {
      const resourceType = e.target.options.resource_type;
      const route = App.MapPopup.getPopupDataUrl(resourceType, e.target.options);

      if (!route) return;

      $.ajax(route, {
        type: "GET",
        dataType: "json",
        success: (data) => {
          const isInModal = !!$(this.element).data('modal-map');
          e.target.bindPopup(
            App.MapPopup.generatePopupContent(data, resourceType, isInModal),
            { autoPanPadding: [0, 80], minWidth: 200, offset: L.point(0, -30) }
          ).openPopup();
        }
      });
    }

    // Form update methods
    updateCenterMarkerFormFields() {
      console.log("updateCenterMarkerFormFields");
      $(this.latitudeInputSelector).val(this.centerMarker.getLatLng().lat);
      $(this.longitudeInputSelector).val(this.centerMarker.getLatLng().lng);
    }

    updateFormShapeFields() {
      // Don't update during shape removal to prevent recursion
      if (this.isRemovingShapes) {
        return;
      }

      $(this.zoomInputSelector).val(this.map.getZoom());

      if (this.adminEditor) {
        // For admin editor, collect all markers and shapes
        const allFeatures = [];

        // Get all geomal points and shapes
        this.map.pm.getGeomanLayers().forEach((geomanLayer) => {
          console.log("Checking geomanLayer:", geomanLayer);
          console.log("geoman layer is center_marker", geomanLayer.options.center_marker)
          // Filter center marker
          if (geomanLayer.options.center_marker !== true) {
            let layerCopy = geomanLayer;

            if (geomanLayer.options.shape === 'Circle') {
              layerCopy = L.PM.Utils.circleToPolygon(geomanLayer, 60);
            }

            const feature = layerCopy.toGeoJSON();
            feature.properties = feature.properties || {};
            feature.properties.from_admin = true;
            feature.properties.fa_icon_class = 'circle';
            console.log("push feature 2", feature);
            allFeatures.push(feature);
          }
        });

        if (allFeatures.length > 0) {
          // Create FeatureCollection for multiple features
          const featureCollection = {
            type: 'FeatureCollection',
            features: allFeatures
          };
          $(this.shapeInputSelector).val(JSON.stringify(featureCollection));

        } else if (this.centerMarker) {
          console.log("single marker case in updateFormShapeFields");
          // $(this.latitudeInputSelector).val(this.centerMarker.getLatLng().lat);
          // $(this.longitudeInputSelector).val(this.centerMarker.getLatLng().lng);
          // $(this.shapeInputSelector).val(JSON.stringify({}));
        }

        $(this.showAdminShapeInputSelector).val(true);
      }
    }

    // Content rendering methods
    // renderMarkerAndShapes() {
    // }

    renderAdminShapes() {
      if (!this.adminShape || !this.showAdminShape) return;

      // Handle both single admin shape and array of admin shapes
      const adminShapes = Array.isArray(this.adminShape) ? this.adminShape : [this.adminShape];

      adminShapes.forEach((singleAdminShape) => {
        if (App.Map.isCenterMarkerCoordinate(singleAdminShape)) {
          if (this.adminEditor) {
            this.createMarker(
              singleAdminShape.lat,
              singleAdminShape.long,
              this.adminShapesColor,
              singleAdminShape.fa_icon_class || 'circle'
            );
          } else {
            const markerLatLng = new L.LatLng(singleAdminShape.lat, singleAdminShape.long);
            const adminMarker = L.marker(markerLatLng, {
              icon: this.getMarkerIcon(this.adminShapesColor, singleAdminShape.fa_icon_class || 'circle'),
              adminMarker: true
            });
            adminMarker.pm.setOptions({ adminShape: true });

            if (!this.editable) {
              adminMarker.on("click", function() {
                if (!this._popup) {
                  this.bindPopup(App.MapPopup.adminShapePopupHtml()).openPopup();
                }
              });
            }

            adminMarker.addTo(this.map);
          }
        } else if (Object.keys(singleAdminShape).length > 0) {
          // Handle FeatureCollection with multiple features
          const features = singleAdminShape.features || [singleAdminShape];

          features.forEach((feature) => {
            if (Object.keys(feature).length) {
              const adminShapeLayer = L.geoJSON(feature, {
                pointToLayer: (geoFeature, latlng) => {
                  return L.marker(latlng, {
                    icon: this.getMarkerIcon(
                      geoFeature.properties.color || this.adminShapesColor,
                      geoFeature.properties.fa_icon_class || 'circle'
                    )
                  });
                }
              });

              adminShapeLayer.pm.setOptions({ adminShape: true });
              adminShapeLayer.setStyle({
                color: feature.properties.color || this.adminShapesColor,
                fillColor: feature.properties.color || this.adminShapesColor,
                fillOpacity: 0.2,
              });

              if (this.adminEditor) {
                this.addEventListenersToShapeLayer(adminShapeLayer);
              } else {
                adminShapeLayer.on("click", function() {
                  if (!this._popup) {
                    this.bindPopup(App.MapPopup.adminShapePopupHtml()).openPopup();
                  }
                });
              }

              adminShapeLayer.addTo(this.map);
            }
          });
        }
      });
    }

    renderProcessCoordinates() {
      if (!this.processCoordinates) return;

      console.log({processCoordinates: this.processCoordinates});

      this.processCoordinates.forEach((markerCoordinate) => {
        if (App.Map.isCenterMarkerCoordinate(markerCoordinate)) {
          this.renderCenterMaker(markerCoordinate);

        } else if (markerCoordinate.features && Array.isArray(markerCoordinate.features)) {
          // Handle GeoJSON FeatureCollection
          markerCoordinate.features.forEach((feature) => {
            this.renderGeoJsonFeature(feature, markerCoordinate)
          });
        } else if (isKeyEmpty(markerCoordinate, "lat") && isKeyEmpty(markerCoordinate, "long")) {
          return
        } else {
          // Handle single GeoJSON feature or legacy format
          if (Object.keys(markerCoordinate).length) {
            console.log("handle single GeoJSON", markerCoordinate);
            const userShape = L.geoJSON(markerCoordinate, {
              style: () => {
                return { color: (markerCoordinate.color || App.Utils.getBrandColor()) };
              }
            });

            userShape.options.id = markerCoordinate.id;
            userShape.options.resource_type = markerCoordinate.resource_type;
            userShape.options.projekt_phase_id = markerCoordinate.projekt_phase_id;

            if (!this.editable && !this.dontOpenMarkerPopup) {
              if (App.MapPopup.excludedProcesses.indexOf(this.process) === -1) {
                userShape.on("click", this.openMarkerPopup);
              }
            }
            userShape.addTo(this.deflateFeatures);
            userShape.addTo(this.map);
          }
        }
      });
    }

    renderAdminShapeInstructionNote() {
      if (!this.showAdminShape) return;

      const adminShapeExplainerText = 'Alle markierten Flächen und Pins in rot sind vom System vorgegeben';
      const adminShapeExplainer = L.control({
        position: 'bottomleft'
      });

      adminShapeExplainer.onAdd = () => {
        const container = L.DomUtil.create('div', 'my-attribution');
        container.innerHTML = adminShapeExplainerText;
        container.className += ' leaflet-control-attribution';
        container.style.color = this.adminShapesColor;
        return container;
      };

      adminShapeExplainer.addTo(this.map);
    }

    // Editing controls setup
    setupEditingControls() {
      if (!this.editable) return;

      // Set default language to German
      this.map.pm.setLang('de');

      // Set positions for geoman controls
      this.map.pm.Toolbar.setBlockPosition('draw', 'topright');
      this.map.pm.Toolbar.setBlockPosition('edit', 'topright');

      // Remove unnecessary controls
      this.map.pm.addControls({
        drawMarker: false,
        drawCircleMarker: false,
        drawText: false,
        removalMode: false
      });

      if (!this.enableGeomanControls) {
        this.map.pm.addControls({
          drawPolyline: false,
          drawRectangle: false,
          drawPolygon: false,
          drawCircle: false,
          editMode: false,
          dragMode: false,
          cutPolygon: false,
          rotateMode: false,
          oneBlock: true
        });
      }

      this.addCustomControls();
      this.setupGeomanEvents();
      this.setShapeColors();
    }

    addCustomControls() {
      // Add consul marker control
      if ((this.enableGeomanControls && !this.adminEditor) || (this.adminEditor && this.setAdminCenterWithMarker)) {
        let iconToUseForCenterMarker;

        if (this.adminEditor && this.setAdminCenterWithMarker) {
          iconToUseForCenterMarker = "leaflet-pm-icon-circle-marker"
        } else if (this.enableGeomanControls && !this.adminEditor) {
          iconToUseForCenterMarker = "leaflet-pm-icon-marker"
        }

        this.map.pm.Toolbar.createCustomControl({
          name: 'consulMarker',
          className: `control-icon ${iconToUseForCenterMarker}`,
          title: 'Einzelner Marker',
          block: 'draw',
          onClick: (_event, { button }) => {
            const toggleStatus = button._button.toggleStatus;

            if (toggleStatus) {
              // Button is being turned off
              this.map.off("click", this.moveOrPlaceCenterMarker);
              this.map.off("click", this.placeMultiMarker);
            } else {
              this.map.off("click", this.placeMultiMarker);
              this.map.on("click", this.moveOrPlaceCenterMarker);
            }
          }
        });
      }

      // Add multi markers control for admin
      if (this.adminEditor) {
        this.map.pm.Toolbar.createCustomControl({
          name: 'multipleMarkers',
          className: 'control-icon leaflet-pm-icon-marker',
          title: 'Mehrere Marker setzen',
          block: 'draw',
          onClick: (_event, {button}) => {
            const toggleStatus = button._button.toggleStatus;

            if (toggleStatus) {
              this.map.off("click", this.placeMultiMarker);
            } else {
              // if (this.enableGeomanControls) {
              //   this.map.pm.Toolbar.toggleButton('consulMarker', false);
              // }
              this.map.off("click", this.moveOrPlaceCenterMarker);
              this.map.on("click", this.placeMultiMarker);
            }
          }
        });
      }

      // Add clear map control
      this.map.pm.Toolbar.createCustomControl({
        name: 'clearMap',
        className: 'control-icon leaflet-pm-icon-delete',
        title: 'Karte zurücksetzen',
        block: 'edit',
        onClick: () => {
          this.removeShapesAndMarkers();

          if (this.enableGeomanControls) {
            this.map.pm.Toolbar.toggleButton('clearMap', true);
            this.map.off("click", this.moveOrPlaceCenterMarker);
            this.map.off("click", this.placeMultiMarker);
          } else {
            this.map.pm.Toolbar.toggleButton('clearMap', false);
            this.map.pm.Toolbar.toggleButton('consulMarker', true);
            this.map.off("click", this.placeMultiMarker);
            this.map.on("click", this.moveOrPlaceCenterMarker);
          }
        },
        afterClick: () => {
          if (!this.enableGeomanControls) {
            $(".control-icon.leaflet-pm-icon-delete").closest(".active").removeClass("active");
          }

          $(this.shapeInputSelector).val(JSON.stringify({}));

          if (this.adminEditor) {
            $(this.showAdminShapeInputSelector).val(false);
          }
        }
      });

      // Toggle consul marker button by default for regular users
      if (!this.adminEditor) {
        this.map.pm.Toolbar.toggleButton('consulMarker', true)
        this.map.on("click", this.moveOrPlaceCenterMarker);
      }

      // Reorder controls
      if (this.enableGeomanControls) {
        const controlOrder = ['consulMarker'];
        if (this.adminEditor) {
          controlOrder.push('multipleMarkers');
        }
        this.map.pm.Toolbar.changeControlOrder(controlOrder);
      }
    }

    setupGeomanEvents() {
      // Remove past elements when new element is started, except for cutting
      this.map.on('pm:drawstart', (e) => {
        if (e.shape === 'Cut') {
          return;
        }

        // Turn off marker modes when any drawing tool starts
        this.turnOffMarkerModes();

        // Only remove existing elements if not in admin editor mode and not already removing
        if (!this.adminEditor && !this.isRemovingShapes) {
          this.removeShapesAndMarkers();
        }
      });

      // Turn off marker modes when any built-in geoman tool is activated
      this.map.on('pm:buttonclick', (e) => {
        // Don't turn off marker modes for our custom controls
        if (e.btnName !== 'consulMarker' && e.btnName !== 'multipleMarkers' && e.btnName !== 'clearMap') {
          this.turnOffMarkerModes();
          // Turn off our custom buttons
          if (this.enableGeomanControls) {
            this.map.pm.Toolbar.toggleButton('consulMarker', false);
          }
          if (this.adminEditor) {
            this.map.pm.Toolbar.toggleButton('multipleMarkers', false);
          }
        }
      });

      // Add newly created shape to form field
      this.map.on('pm:create', (e) => {
        const layer = e.layer;

        if (e.shape === 'Circle') {
          layer.options.shape = 'Circle';
        }

        this.updateFormShapeFields(layer);
        this.addEventListenersToShapeLayer(layer);
      });

      // Handle shape deletion in admin mode
      this.map.on('pm:remove', () => {
        if (this.adminEditor && !this.isRemovingShapes) {
          setTimeout(() => {
            this.updateFormShapeFields(null);
          }, 10);
        }
      });
    }

    // Helper method to turn off marker click modes
    turnOffMarkerModes() {
      this.map.off("click", this.moveOrPlaceCenterMarker);
      this.map.off("click", this.placeMultiMarker);
    }

    addEventListenersToShapeLayer(layer) {
      layer.on('pm:edit', (e) => {
        this.updateFormShapeFields(e.layer);
      });

      layer.on('pm:dragend', (e) => {
        this.updateFormShapeFields(e.layer);
      });

      // Allow multiple cuts
      layer.on('pm:cut', (e) => {
        if (typeof(e.layer.getLatLngs) === 'function') {
          e.originalLayer.setLatLngs(e.layer.getLatLngs());
          e.originalLayer.addTo(this.map);
          e.originalLayer._pmTempLayer = false;

          e.layer._pmTempLayer = true;
          e.layer.remove();

          // Update form fields after cut operation in admin mode
          if (this.adminEditor) {
            setTimeout(() => {
              this.updateFormShapeFields(null);
            }, 10);
          }
        }
      });
    }

    renderCenterMaker(markerCoordinate) {
      console.log("render centerMaker", markerCoordinate);

      const marker = this.createMarker(
        markerCoordinate.lat,
        markerCoordinate.long,
        markerCoordinate.color,
        markerCoordinate.fa_icon_class,
        markerCoordinate.center_marker
      );

      marker.options.id = markerCoordinate.id;
      marker.options.resource_type = markerCoordinate.resource_type;
      marker.options.projekt_phase_id = markerCoordinate.projekt_phase_id;

      if (!this.editable && !this.dontOpenMarkerPopup) {
        if (App.MapPopup.excludedProcesses.indexOf(this.process) === -1) {
          marker.on("click", this.openMarkerPopup);
        }
      }

      if (this.editable) {
        this.centerMarker = marker;
      }
    }

    renderGeoJsonFeature(feature, markerCoordinate) {
      if (feature.geometry.type === 'Point') {
        this.renderGeoJsonPoint(feature, markerCoordinate)
      } else {
        if (Object.keys(feature).length) {
          this.renderGeoJsonShape(feature, markerCoordinate)
        }
      }
    }

    renderGeoJsonPoint(feature, markerCoordinate) {
      console.log("renderGeoJsonPoint", feature, markerCoordinate)
      // Render Point features as regular markers
      const coords = feature.geometry.coordinates;
      let markerColor = '';
      const iconClass = (feature.properties.fa_icon_class || markerCoordinate.fa_icon_class);

      // if (feature.properties.from_admin) {
      if (this.adminEditor) {
        markerColor = this.adminShapesColor;
      } else {
        markerColor = (feature.properties.color || markerCoordinate.color);
      }

      const featureMarker = this.createMarker(
        coords[1], // latitude
        coords[0], // longitude
        markerColor,
        iconClass
      );

      featureMarker.options.id = markerCoordinate.id;
      featureMarker.options.resource_type = markerCoordinate.resource_type;
      featureMarker.options.projekt_phase_id = markerCoordinate.projekt_phase_id;

      if (!this.editable && !this.dontOpenMarkerPopup) {
        if (App.MapPopup.excludedProcesses.indexOf(this.process) === -1) {
          featureMarker.on("click", this.openMarkerPopup);
        }
      }
    }

    renderGeoJsonShape(feature, markerCoordinate) {
      const userShape = L.geoJSON(feature, {
        style: (geoFeature) => {
          let color;

          if (this.adminEditor) {
            color = this.adminShapesColor;
          }
          else {
            color = geoFeature.properties.color || markerCoordinate.color || feature.properties.color
          }

          return { color };
        }
      });

      userShape.options.id = markerCoordinate.id;
      userShape.options.resource_type = markerCoordinate.resource_type;
      userShape.options.projekt_phase_id = markerCoordinate.projekt_phase_id;

      if (!this.editable) {
        if (App.MapPopup.excludedProcesses.indexOf(this.process) === -1) {
          userShape.on("click", this.openMarkerPopup);
        }
      }
      userShape.addTo(this.deflateFeatures);
      userShape.addTo(this.map);
    }

    setShapeColors() {
      if (this.adminEditor) {
        this.map.pm.setPathOptions({
          color: this.adminShapesColor,
          fillColor: this.adminShapesColor,
          fillOpacity: 0.4
        });
        this.map.pm.setGlobalOptions({
          templineStyle: { color: this.adminShapesColor },
          hintlineStyle: { color: this.adminShapesColor, dashArray: [5, 5] }
        });
      } else {
        const brandColor = App.Utils.getBrandColor();
        this.map.pm.setPathOptions({
          color: brandColor,
          fillColor: brandColor,
          fillOpacity: 0.4
        });
      }
    }

    removeShapesAndMarkers() {
      if (this.isRemovingShapes) {
        console.warn('removeShapesAndMarkers: Already removing shapes, preventing recursion');
        return;
      }

      this.centerMarker = null;
      this.isRemovingShapes = true;

      try {
        // Temporarily disable PM event handlers to prevent cascading events
        let tempHandlers = [];

        // Store and remove pm:remove handler temporarily
        this.map.pm._eventData = this.map.pm._eventData || {};
        const removeHandlers = this.map._events && this.map._events['pm:remove'] || [];
        if (removeHandlers.length > 0) {
          tempHandlers = removeHandlers.slice(); // Copy handlers
          this.map._events['pm:remove'] = []; // Clear handlers temporarily
        }

        // Get all layers first, then remove them to avoid modifying collection during iteration
        const layersToRemove = [];
        try {
          this.map.pm.getGeomanLayers().forEach((layer) => {
            if (layer.pm.options.adminShape !== true || this.adminEditor) {
              layersToRemove.push(layer);
            }
          });
        } catch (e) {
          console.warn('Error getting geoman layers:', e);
        }

        // Remove layers outside of the iteration with minimal event triggering
        layersToRemove.forEach((layer) => {
          try {
            // Use more direct removal to avoid event cascades
            if (layer._map) {
              layer._map.removeLayer(layer);
            } else {
              layer.remove();
            }
          } catch (e) {
            console.warn('Error removing layer:', e);
          }
        });

        // Restore PM event handlers
        if (tempHandlers.length > 0 && this.map._events) {
          this.map._events['pm:remove'] = tempHandlers;
        }

        // Clear shape data but preserve latitude and longitude
        $(this.shapeInputSelector).val(JSON.stringify({}));

        if (!this.adminEditor) {
          $(this.showAdminShapeInputSelector).val(false);
        }

      } catch (error) {
        console.error('Error in removeShapesAndMarkers:', error);
      } finally {
        this.isRemovingShapes = false;
      }
    }

    // Public Interface method for assistant map update and external use
    // DO NOT DELETE
    setMarkerTo(lat, lng, shouldScroll) {
      this.map.panTo(new L.LatLng(lat, lng));

      if (this.centerMarker) {
        this.centerMarker.setLatLng([lat, lng]);
      } else {
        this.centerMarker = this.createMarker(lat, lng);
      }

      if (shouldScroll) {
        this.map.getContainer().scrollIntoView({
          block: "center", inline: "nearest"
        })
      }

      this.updateCenterMarkerFormFields();
    }

    // Cleanup method
    destroy() {
      this.map.off();
      this.map.remove();
    }

    panTo(coordinates) {
      this.map.panTo(coordinates)
    }
  }

  function isKeyEmpty(obj, key) {
    return obj.hasOwnProperty(key) && (
      obj[key] === null ||
      obj[key] === undefined ||
      obj[key] === '' ||
      (typeof obj[key] === 'object' && Object.keys(obj[key]).length === 0)
    );
  }

  window.App.LeafletMapController = LeafletMapController;
}).call(this);


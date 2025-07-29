(function() {
  "use strict";

  class MapboxMapController {
    constructor(element) {
      this.element = element;
      var $element = $(element);

      this.mapCenterLatitude = $element.data("map-center-latitude");
      this.mapCenterLongitude = $element.data("map-center-longitude");
      this.zoom = $element.data("map-zoom");
      this.resourcesName = $element.data("parent-class");
      this.markerCoordinates = $element.data("process-coordinates");
      this.adminEditor = $element.data("admin-editor");
      this.editable = $element.data("editable") || this.adminEditor;
      this.enableGeomanControls = $element.data("enable-geoman-controls");
      this.adminShape = $element.data("admin-shape");
      this.saturatedAdminShape = $element.data("saturated-admin-shape")
      this.showAdminShape = $element.data("show-admin-shape");
      this.latitudeInputSelector = $element.data("latitude-input-selector");
      this.longitudeInputSelector = $element.data("longitude-input-selector");
      this.altitudeInputSelector = $element.data("altitude-input-selector");
      this.zoomInputSelector = $element.data("zoom-input-selector");
      this.shapeInputSelector = $element.data("shape-input-selector");
      this.showAdminShapeInputSelector = $element.data("show-admin-shape-input-selector");
      this.$categorySelect = $(".js-map-update-pin-style");
      this.markerImages = $element.data("mapbox-marker-images")
      this.styleId = $element.data("mapbox-style-id")
      this.layersData = $element.data('map-layers')
      this.dontOpenMarkerPopup = $element.data('dont-open-marker-popup')
      this.setAdminCenterWithMarker = $element.data('set-admin-center-with-marker');

      this.map = null;
      this.baseLayers = {}; // Store base layer sources
      this.overlayLayers = {}; // Store overlay layer sources
      // this.pinMarkers = []; // Array to store all marker-coordinates
      this.adminMarker = null;
      this.centerMarker = null; // Single editable marker for user interaction
      this.markerCategoryIcon = null;
      this.markerCategoryColor = null;

      this.colors = $element.data("colors");
      this.adminShapesColor = this.colors.admin_shapes;
      this.projektCenterMarkerColor = this.colors.projekt_center_marker;

      this.defaultMarkerBackgroundCircleRadius = 14;
      this.hoveredFeature = null;
      this.draw = null; // Mapbox Draw instance for polygon editing

      if (this.editable) {
        this.touchStartTime = null;
        this.touchStartPoint = null;
        this.touchMoved = false;
        this.touchThreshold = 10; // pixels
        this.tapThreshold = 300; // milliseconds
      }

      this.initialize();
    }

    initialize() {
      this.map = this.initializeMap();
      this.mapLoaded = false; // Track map loading state

      // Wait for the map to load before adding marker-coordinates
      this.map.on('load', () => {
        this.mapLoaded = true;

        // Render base and overlay layers first for proper layer ordering
        this.renderWmsLayers();
        this.addLayerControl();
        this.addControls();

        this.renderAdminShape();

        // // User shapes
        this.renderMarkerCoordinates();
        this.renderResourceShapes();

        this.addMapInstructionOverlay();
      });

      this.setupEventListeners();

      this.setupMarkerCategorySelection();
    }

    initializeMap() {
      mapboxgl.accessToken = this.element.dataset.mapboxPublicToken;

      var mapSettings = {
        container: this.element,
        center: [this.mapCenterLongitude, this.mapCenterLatitude],
        zoom: this.zoom,
        pitch: 53
      }

      if (this.styleId) {
        mapSettings.style = this.styleId;
      }

      return new mapboxgl.Map(mapSettings);
    }

   setupEventListeners() {
      if (this.adminEditor) {
        this.map.on("moveend", this.handleMoveEnd);
      }

      if (this.editable) {
        // Track touch state to distinguish between taps and drags
        this.map.on('touchstart', this.handleTouchStart);
        this.map.on('touchmove', this.handleTouchMove);

        if (!this.adminEditor || (this.adminEditor && this.setAdminCenterWithMarker)) {
          this.map.on('click', this.handleMapInteractionForMoveOrPlaceCenterMarker.bind(this));
          this.map.on('touchend', this.handleMapInteractionForMoveOrPlaceCenterMarker.bind(this));
        }
      }
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

    handleMoveEnd = (e) => {
      var center = this.map.getCenter();
      $(this.latitudeInputSelector).val(center.lat);
      $(this.longitudeInputSelector).val(center.lng);
      $(this.altitudeInputSelector).val(0); // Set altitude to 0 for map center updates
      $(this.zoomInputSelector).val(this.map.getZoom());
    }

    handleTouchStart = (e) => {
      this.touchStartTime = Date.now();
      this.touchStartPoint = e.point;
      this.touchMoved = false;
    }

    handleTouchMove = (e) => {
      if (this.touchStartPoint) {
        var distance = Math.sqrt(
          Math.pow(e.point.x - this.touchStartPoint.x, 2) +
          Math.pow(e.point.y - this.touchStartPoint.y, 2)
        );
        if (distance > this.touchThreshold) {
          this.touchMoved = true;
        }
      }
    }

    handleMapInteractionForMoveOrPlaceCenterMarker = (e) => {
      console.log("handleMapInteractionForMoveOrPlaceCenterMarker")
      // For touch events, only proceed if it was a tap (not a drag)
      if (e.type === 'touchend') {
        var touchDuration = Date.now() - this.touchStartTime;
        if (this.touchMoved || touchDuration > this.tapThreshold) {
          return; // Don't place marker if touch moved or was too long
        }
      }

      // Check if interaction is on a draw control button
      var target = e.originalEvent ? e.originalEvent.target : e.target;
      var isDrawControl = target && (
        target.classList.contains('mapbox-gl-draw_ctrl-draw-btn') ||
        target.closest('.mapbox-gl-draw_ctrl')
      );

      // Check for all interactive features (markers, shapes, clusters)
      var markerFeatures = this.map.queryRenderedFeatures(e.point, {
        layers: ['custom-marker', 'custom-marker-icon', 'clusters']
      });

      var userShapeFeatures = [];
      var allLayers = this.map.getStyle().layers;

      allLayers.forEach((layer) => {
        // Only check user shapes - admin shapes should not prevent marker placement in edit mode
        if (layer.id.includes('user-shape-')) {
          var layerFeatures = this.map.queryRenderedFeatures(e.point, {
            layers: [layer.id]
          });
          if (layerFeatures.length > 0) {
            userShapeFeatures = userShapeFeatures.concat(layerFeatures);
          }
        }
      });

      // Check current draw mode
      var currentMode = 'simple_select';
      if (this.draw) {
        currentMode = this.draw.getMode();
      }

      var drawFetures = this.draw ? this.draw.getAll().features : [];

      // Check if there are existing draw features
      var hasExistingDrawFeatures = this.draw && drawFetures.length > 0;
      var hasOnlyPointDrawFeatures = drawFetures.length === 1 && drawFetures[0].geometry.type.toLowerCase() === "point"

      // Place editable marker if:
      // - No conflicting features clicked (markers, user shapes, or clusters)
      // - Not clicked on draw controls
      // - No existing draw features (to avoid conflicts)
      // if (hasOnlyPointDrawFeatures || (markerFeatures.length === 0 && userShapeFeatures.length === 0 && !isDrawControl && !hasExistingDrawFeatures)) {
      if (currentMode === "simple_select") {
        this.moveOrPlaceMarker(e);
      }
    };

    addControls() {
      // Always add fullscreen control on all screen sizes (if not in modal and not editable)
      if (!this.element.dataset.modalMap && !this.editable) {
        this.map.addControl(new FullscreenModalControl(this), 'top-right');
      }

      // Only add other controls on larger screens to avoid clutter
      if (this.element.offsetWidth > 580) {
        // Add zoom/navigation controls first (leftmost)
        this.map.addControl(new mapboxgl.NavigationControl(), 'top-left');

        // Add search bar to the right of zoom controls
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

      if (this.editable && typeof MapboxDraw !== 'undefined') {
        this.initializePolygonEditor();
      }
    }

    addMapInstructionOverlay() {
      if (this.element.offsetWidth <= 780) {
        return;
      }

      var overlay = document.createElement('div');
      overlay.className = 'mapbox-instruction-overlay';

      // Build instruction text based on whether admin shapes are shown
      var instructionText = '<span class="mapbox-instruction-text">Klicken Sie auf die Karte um Marker zu platzieren</span>';

      if (this.showAdminShape) {
        instructionText += '<div class="adminShapeInfo" style="color: ' + this.adminShapesColor + ';">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>';
      }

      overlay.innerHTML = instructionText;

      this.element.style.position = 'relative';
      this.element.appendChild(overlay);

      // Store reference for cleanup
      this.instructionOverlay = overlay;
    }

    updateMarkerStyleFromCategorySelect(element) {
      const selectedOption = element.options[element.selectedIndex];
      this.userMarkerCategoryIcon = selectedOption.dataset.icon;
      this.userMarkerCategoryColor = selectedOption.dataset.color;
      this.updateMarkerWithCategoryStyle();
    }

    addCustomDeleteButton() {
      if (!this.draw) return;

      var customDeleteControl = new CustomDeleteControl(this);
      this.map.addControl(customDeleteControl, 'top-right');
    }

    togglePoiLabels(visible) {

      if (!this.mapLoaded) {
        this.map.once('idle', () => {
          this.togglePoiLabels(visible);
        });
        return;
      }

      var layers = this.map.getStyle().layers;
      var visibility = visible ? 'visible' : 'none';

      layers.forEach((layer) => {
        if (layer.id.toLowerCase() === "poi-label") {
          try {
            this.map.setLayoutProperty(layer.id, 'visibility', visibility);
          } catch (e) {
            console.warn('Could not toggle visibility for layer:', layer.id, e);
          }
        }
      });
    }

    getDrawStyles() {
      // const blue = '#3bb2d0';
      const orange = '#fbb03b';
      const brandColor =  App.Utils.getBrandColor();
      const white = '#fff';
      var circleColor = this.markerCategoryColor || (this.adminEditor ? this.adminShapesColor : '#ff0000');
      const shapesColor = this.adminEditor ? this.adminShapesColor : brandColor;

      return [
        // // Bigger points
        // {
        //   'id': 'gl-draw-point-point-stroke-inactive',
        //   'type': 'circle',
        //   'filter': ['all', ['==', '$type', 'Point'], ['==', 'meta', 'feature'], ['!=', 'mode', 'static']],
        //   'paint': {
        //     'circle-radius': 12,
        //     'circle-color': color,
        //     'circle-stroke-width': 3,
        //     'circle-stroke-color': '#ffffff'
        //   }
        // },

        // Polygons
        //   Solid fill
        //   Active state defines color
        {
          'id': 'gl-draw-polygon-fill',
          'type': 'fill',
          'filter': [
            'all',
            ['==', '$type', 'Polygon'],
          ],
          'paint': {
            'fill-color': [
              'case',
              ['==', ['get', 'active'], 'true'], orange,
              shapesColor
            ],
            'fill-opacity': [
              'case',
              ['==', ['get', 'active'], 'true'], 0.35,
              0.15
            ],
          },
        },

        // Lines
        // Polygon
        //   Matches Lines AND Polygons
        //   Active state defines color
        {
          'id': 'gl-draw-lines',
          'type': 'line',
          'filter': [
            'any',
            ['==', '$type', 'LineString'],
            ['==', '$type', 'Polygon'],
          ],
          'layout': {
            'line-cap': 'round',
            'line-join': 'round',
          },
          'paint': {
            'line-color': [
              'case',
              ['==', ['get', 'active'], 'true'], orange,
              shapesColor,
            ],
            'line-dasharray': [
              'case',
              ['==', ['get', 'active'], 'true'], [5, 5],
              [5, 0],
            ],
            'line-width': [
              'case',
              ['==', ['get', 'active'], 'true'], 5,
              2,
            ]
          },
        },

        // Points
        //   Circle with an outline
        //   Active state defines size and color
        {
          'id': 'gl-draw-point-outer',
          'type': 'circle',
          'filter': [
            'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'feature'],
          ],
          'paint': {
            'circle-radius': [
              'case',
              ['==', ['get', 'active'], 'true'], 15,
              15,
            ],
            'circle-color': white,
          },
        },
        {
          'id': 'gl-draw-point-inner',
          'type': 'circle',
          'filter': [
            'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'feature'],
          ],
          'paint': {
            'line-color': [
              'case',
              ['==', ['get', 'active'], 'true'], white,
              white,
            ],
            'circle-radius': [
              'case',
              ['==', ['get', 'active'], 'true'], 12,
              12,
            ],
            'circle-color': [
              'case',
              ['==', ['get', 'active'], 'true'], orange,
              circleColor,
            ],
          },
        },


        // Vertex
        //   Visible when editing polygons and lines
        //   Similar behaviour to Points
        //   Active state defines size
        {
          'id': 'gl-draw-vertex-outer',
          'type': 'circle',
          'filter': [
            'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'vertex'],
            ['!=', 'mode', 'simple_select'],
          ],
          'paint': {
            'circle-radius': [
              'case',
              ['==', ['get', 'active'], 'true'], 8,
              9,
            ],
            'circle-color': white
          },
        },
        {
          'id': 'gl-draw-vertex-inner',
          'type': 'circle',
          'filter': [
            'all',
            ['==', '$type', 'Point'],
            ['==', 'meta', 'vertex'],
            ['!=', 'mode', 'simple_select'],
          ],
          'paint': {
            'circle-radius': [
              'case',
              ['==', ['get', 'active'], 'true'], 5,
              7,
            ],
            'circle-color': orange
          },
        },
      ];
    }

    initializePolygonEditor() {
      var controls = {}

      if (this.enableGeomanControls) {
        controls.trash = true;
        controls.line = true;
        controls.point = true;
        controls.polygon = true;
      }

      // const defaultMode = this.adminEditor ? 'draw_point' : 'simple_select';
      const defaultMode = 'simple_select';

      this.draw = new MapboxDraw({
        displayControlsDefault: false,
        controls: controls,
        defaultMode,
        styles: this.getDrawStyles()
      });

      this.map.addControl(this.draw);
      this.addCustomDeleteButton();
      this.loadFormInputShape();

      this.setupDrawEventListeners();
      this.setupDrawCursorEffects();
    };

    loadFormInputShape() {
      // Try to load existing shape data from the shape input field
      if (this.shapeInputSelector) {
        var shapeData = $(this.shapeInputSelector).val();
        if (shapeData && shapeData.trim() !== '' && shapeData !== '{}') {
          try {
            var existingShape = JSON.parse(shapeData);
            if (existingShape && existingShape.type) {
              // Add the existing shape to the draw instance
              this.draw.add(existingShape);
            }
          } catch (e) {
            console.warn('Could not parse existing shape data:', e);
          }
        }
      }
    }

    setupDrawEventListeners() {
      // Update form fields when shapes are created, updated, or deleted
      this.map.on('draw.create', this.handleDrawCreate);

      this.map.on('draw.update', (e) => {
        this.updateShapeFormFields();
      });

      this.map.on('draw.delete', (e) => {
        this.updateShapeFormFields();
      });

      // Listen for mode changes to help with conflict resolution
      this.map.on('draw.modechange', (e) => {
        // If entering a drawing mode, clear any existing marker-coordinates
        if (e.mode.startsWith('draw_')) {
        //   this.removeCenterMarker();
        }
      });

      // Track mouse state for distinguishing clicks from drags
      var mouseDownPoint = null;
      var isDragging = false;

      this.map.on('mousedown', function(e) {
        mouseDownPoint = e.point;
        isDragging = false;
      });

      this.map.on('mousemove', function(e) {
        if (mouseDownPoint) {
          var distance = Math.sqrt(
            Math.pow(e.point.x - mouseDownPoint.x, 2) +
            Math.pow(e.point.y - mouseDownPoint.y, 2)
          );
          if (distance > 3) { // 3 pixel threshold
            isDragging = true;
          }
        }
      });

      this.map.on('mouseup', (e) => {
        console.log("handleMouseUp")

        console.log("this.draw.getMode",this.draw.getMode())
        if (this.draw && this.draw.getMode() === 'draw_point' && !isDragging && mouseDownPoint) {
          // Check if we clicked on an existing draw feature
          var clickedFeatures = this.map.queryRenderedFeatures(e.point);
          var targetFeatureId = null;

          clickedFeatures.forEach((feature) => {
            if (feature.source === 'mapbox-gl-draw-cold' || feature.source === 'mapbox-gl-draw-hot') {
              if (feature.properties && feature.properties.id) {
                targetFeatureId = feature.properties.id;
              } else if (feature.properties && feature.properties.parent) {
                targetFeatureId = feature.properties.parent;
              }
            }
          });

          if (targetFeatureId) {
            // Switch to select mode and select the clicked feature
            this.draw.changeMode('simple_select', {
              featureIds: [targetFeatureId]
            });
          }
        }

        // Reset mouse tracking
        mouseDownPoint = null;
        isDragging = false;
      });
    }

    handleDrawCreate = (e) => {
      console.log("handleDrawCreate")
      var wasInPointMode = this.draw.getMode() === 'draw_point';

      // If not admin editor, ensure only one polygon exists
      if (!this.adminEditor) {
        var allFeatures = this.draw ? this.draw.getAll() : { features: [] };
        // If we have more than one feature, remove all but the newest one
        if (allFeatures.features.length > 1) {
          // Get the newly created feature(s) from the event
          var newFeatureIds = e.features.map((feature) => {
            return feature.id;
          });

          // Delete all features except the newly created ones
          var featuresToDelete = allFeatures.features.filter((feature) => {
            return newFeatureIds.indexOf(feature.id) === -1;
          });

          var idsToDelete = featuresToDelete.map((feature) => {
            return feature.id;
          });

          if (idsToDelete.length > 0) {
            this.draw.delete(idsToDelete);
          }
        }
      }

      this.updateShapeFormFields();
      // Remove any existing marker-coordinates when a shape is created
      this.removeCenterMarker();

      // Keep point drawing mode active after creating a point
      // if (wasInPointMode && e.features.length > 0 && e.features[0].geometry.type === 'Point') {
      //   setTimeout(() => {
      //     if (this.draw) {
      //       console.log("changeMode to draw_point")
      //       this.draw.changeMode('draw_point');
      //     }
      //   }, 50);
      // }
    }

    setupDrawCursorEffects() {
      var isDragging = false;

      // Helper function to check if point has draw features
      const hasDrawFeature = (point) => {
        var features = this.map.queryRenderedFeatures(point);
        return features.some((feature) => {
          return feature.source === 'mapbox-gl-draw-cold' || feature.source === 'mapbox-gl-draw-hot';
        });
      }

      // Track drag state
      this.map.on('mousedown', function(e) {
        isDragging = this.draw && hasDrawFeature(e.point);
      });

      this.map.on('mouseup', function() {
        isDragging = false;
      });

      this.map.on('mousemove', function(e) {
        if (!this.draw) return;

        var cursor = isDragging ? 'move' : hasDrawFeature(e.point) ? 'pointer' : '';
        this.map.getCanvas().style.cursor = cursor;
      });
    }

    updateShapeFormFields() {
      if (!this.draw || !this.shapeInputSelector) return;

      var allFeatures = this.draw.getAll();

      $(this.shapeInputSelector).val(JSON.stringify(allFeatures));

      if (allFeatures.features.length > 0) {
        $(this.altitudeInputSelector).val(''); // Clear altitude when shape is present
      }

      $(this.zoomInputSelector).val(this.map.getZoom());

      if (this.adminEditor && this.showAdminShapeInputSelector) {
        $(this.showAdminShapeInputSelector).val(true);
      }
    }

    getStyledMarker(color, iconClass) {
      if (this.markerCategoryIcon) {
        iconClass = this.markerCategoryIcon;
      } else if (!iconClass) {
        iconClass = 'circle';
      }

      if (this.resourcesName === "projekts") {
        color = this.projektCenterMarkerColor;
      }

      if (this.markerCategoryColor) {
        color = this.markerCategoryColor;
      }

      // if (this.adminEditor) {
      //   color = this.adminShapesColor;
      // }

      return {
        element: this.createMarkerElement(color, iconClass),
        anchor: [0, 0]
      };
    }

    createMarkerElement(color, iconClass) {
      var el = document.createElement('div');
      el.className = 'map-marker';
      var icon = document.createElement('div');
      icon.className = 'map-icon icon-' + iconClass;
      if (color) {
        icon.style.backgroundColor = color;
      }
      el.appendChild(icon);
      return el;
    };

    // createPinMarker(latitude, longitude, color, iconClass) {
    //   var styledMarker = this.getStyledMarker(color, iconClass);
    //   var markerOptions = {
    //     element: styledMarker.element,
    //     anchor: 'bottom',
    //     offset: [0, -10],
    //     draggable: this.editable
    //   };

    //   var pinMarker = new mapboxgl.Marker(markerOptions)
    //     .setLngLat([longitude, latitude]);

    //   if (this.editable) {
    //     pinMarker.on("dragend", this.updateFormfieldsWithMarker.bind(this));
    //   }
    //   pinMarker.addTo(this.map);

    //   // Add pinMarker to our marker-coordinates array
    //   this.pinMarkers.push(pinMarker);

    //   return pinMarker;
    // };

    updateFormfieldsWithMarker(e) {
      var marker = e.target;
      var lngLat = marker.getLngLat();
      $(this.latitudeInputSelector).val(lngLat.lat);
      $(this.longitudeInputSelector).val(lngLat.lng);
      $(this.altitudeInputSelector).val(0); // Set altitude to 0 for marker placement
      $(this.zoomInputSelector).val(this.map.getZoom());
      $(this.shapeInputSelector).val(JSON.stringify({}));

      if (this.adminEditor) {
        $(this.showAdminShapeInputSelector).val(true);
      }
    }

    // Helper method to remove editable marker
    removeCenterMarker() {
      if (this.centerMarker) {
        this.centerMarker.remove();
        this.centerMarker = null;
      }
    }

    // Helper method to delete all user markers (but not admin markers)
    deleteAllUserMarkers() {
      // Remove all pin markers
      // this.pinMarkers.forEach(function(marker) {
      //   try {
      //     marker.remove();
      //   } catch (e) {
      //     console.warn('Error removing pin marker:', e);
      //   }
      // });
      // this.pinMarkers = [];

      // Remove editable marker
      this.removeCenterMarker();

      if (!this.adminEditor) {
        this.clearFormFields();
      }
    }

    // Helper method to clear form fields
    clearFormFields() {
      if (this.latitudeInputSelector) {
        $(this.latitudeInputSelector).val('');
      }
      if (this.longitudeInputSelector) {
        $(this.longitudeInputSelector).val('');
      }
      if (this.altitudeInputSelector) {
        $(this.altitudeInputSelector).val('');
      }
      if (this.shapeInputSelector) {
        $(this.shapeInputSelector).val(JSON.stringify({}));
      }
    }

    // function to create or move existing marker (similar to Leaflet version)
    moveOrPlaceMarker(e) {
      console.log("moveOrPlaceMarker")
      var lngLat = e.lngLat;

      // Clear any existing draw features when placing an editable marker
      console.log("this.draw", this.draw)
      if (this.draw) {
        var allFeatures = this.draw.getAll();
        if (allFeatures.features.length > 0) {
          this.draw.deleteAll();
        }
        console.log("switch draw mode to simple_select")
        // Switch draw mode to simple_select to avoid conflicts
        this.draw.changeMode('simple_select');
      }

      // Move existing marker or create new one
      if (this.centerMarker) {
        this.centerMarker.setLngLat([lngLat.lng, lngLat.lat]);
        this.updateMarkerWithCategoryStyle();
      } else {
        this.centerMarker = this.createCenterMarker(lngLat.lat, lngLat.lng);
      }
      this.updateFormfieldsFromEditableMarker();
    }

    // function to update form fields when editable marker is updated
    updateFormfieldsFromEditableMarker() {
      if (!this.centerMarker) return;

      var lngLat = this.centerMarker.getLngLat();

      $(this.latitudeInputSelector).val(lngLat.lat);
      $(this.longitudeInputSelector).val(lngLat.lng);
      $(this.altitudeInputSelector).val(0); // Set altitude to 0 for editable marker
      $(this.zoomInputSelector).val(this.map.getZoom());
      $(this.shapeInputSelector).val(JSON.stringify({}));

      // Clear any existing polygons when updating marker coordinates
      if (this.draw) {
        this.draw.deleteAll();
      }

      if (this.adminEditor) {
        $(this.showAdminShapeInputSelector).val(true);
      }
    };

    // function to create an editable marker
    createCenterMarker(latitude, longitude) {
      var styledMarker = this.getStyledMarker(null, null);
      var markerOptions = {
        element: styledMarker.element,
        anchor: 'bottom',
        offset: [0, 0],
        draggable: true
      };

      var marker =
        (new mapboxgl.Marker(markerOptions))
        .setLngLat([longitude, latitude]);

      marker.on("dragend", () => {
        this.updateFormfieldsFromEditableMarker();
      });

      marker.addTo(this.map);

      return marker;
    }

    updateMarkerStyleFromCategorySelect(element) {
      var selectedOption = element.options[element.selectedIndex];
      this.markerCategoryIcon = selectedOption.dataset.icon;
      this.markerCategoryColor = selectedOption.dataset.color;
      this.updateMarkerWithCategoryStyle();
    }

    updateMarkerWithCategoryStyle() {
      // if (this.pinMarkers.length) {
      //   this.pinMarkers.forEach(function(marker) {
      //     marker.setIcon(this.getStyledMarker(null, null));
      //   }.bind(this));
      // }

      if (this.centerMarker) {
        var newIcon = this.getStyledMarker(null, null);

        this.centerMarker.getElement().innerHTML = '';
        this.centerMarker.getElement().appendChild(newIcon.element);
      }
    }

    handleUnifiedPopup(e) {
      var self = this;

      // Check for clusters first - they should expand, not show popups
      var clusterFeatures = self.map.queryRenderedFeatures(e.point, {
        layers: ['clusters']
      });

      if (clusterFeatures.length > 0) {
        // Handle cluster expansion
        var clusterId = clusterFeatures[0].properties.cluster_id;
        self.map.getSource('marker-coordinates').getClusterExpansionZoom(
          clusterId,
          function(err, zoom) {
            if (err) return;
            self.map.easeTo({
              center: clusterFeatures[0].geometry.coordinates,
              zoom: zoom
            });
          }
        );
        return;
      }

      // Query features in order of priority (most important first)
      var markerFeatures = self.map.queryRenderedFeatures(e.point, {
        layers: ['custom-marker', 'custom-marker-icon']
      });

      var adminShapeFeatures = [];
      var userShapeFeatures = [];

      // Check for admin and user shape layers
      var allLayers = self.map.getStyle().layers;
      allLayers.forEach(function(layer) {
        if (layer.id.includes('admin-shape-') || layer.id.includes('user-shape-')) {
          var features = self.map.queryRenderedFeatures(e.point, {
            layers: [layer.id]
          });
          if (features.length > 0) {
            if (layer.id.includes('admin-shape-')) {
              adminShapeFeatures = adminShapeFeatures.concat(features);
            } else {
              userShapeFeatures = userShapeFeatures.concat(features);
            }
          }
        }
      });

      // Handle popup based on priority: markers > user shapes > admin shapes
      if (markerFeatures.length > 0) {
        if (!this.dontOpenMarkerPopup) {
          self.openMarkerPopup({
            features: markerFeatures,
            lngLat: e.lngLat
          });
        }
      } else if (userShapeFeatures.length > 0) {
        if (!this.dontOpenMarkerPopup) {
          self.openShapePopup(e, 'user');
        }
      } else if (adminShapeFeatures.length > 0) {
        self.openShapePopup(e, 'admin');
      }
    }

    openMarkerPopup(e) {
      var self = this;

      // Check if we have features and at least one feature
      if (!e.features || !e.features.length || !e.features[0]) {
        return;
      }

      var coordinates = e.features[0].geometry.coordinates.slice();
      var properties = e.features[0].properties;
      var resourceType = properties["resource_type"]

      // Show empty popup immediately
      var popup = new mapboxgl.Popup({
        offset: 20,
        closeButton: true,
        maxWidth: '250px'
      })
        .setLngLat(coordinates)
        .setHTML('<div class="map-popup-status-message">Laden...</div>')
        .addTo(self.map);

      var popupDataUrl = App.MapPopup.getPopupDataUrl(resourceType, properties)

      if (!popupDataUrl) return;

      $.ajax(popupDataUrl, {
        type: "GET",
        dataType: "json"
      })
        .then(function(data) {
          var isInModal = !!self.element.dataset.modalMap;
          popup.setHTML(App.MapPopup.generatePopupContent(data, resourceType, isInModal));
        })
        .fail(function() {
          popup.setHTML('<div class="map-popup-status-message error">Failed to load data</div>');
        })
    }

    openShapePopup(e, shapeType) {
      var self = this;

      if (this.editable || this.dontOpenMarkerPopup) {
        return
      }

      if (shapeType === 'admin') {
        new mapboxgl.Popup({
          offset: 20,
          closeButton: true,
          maxWidth: '250px'
        })
          .setLngLat(e.lngLat)
          .setHTML(App.MapPopup.adminShapePopupHtml())
          .addTo(self.map);
      } else {
        // For user shapes, try to find the original coordinates data to get popup info
        var shapeData = null;
        if (self.markerCoordinates) {
          self.markerCoordinates.forEach(function(coordinate) {
            if (!App.Map.validCoordinates(coordinate) && coordinate.id) {
              // This is likely a shape coordinate
              shapeData = coordinate;
            }
          });
        }

        var popup = new mapboxgl.Popup({
          offset: 20,
          closeButton: true,
          maxWidth: '250px'
        })
          .setLngLat(e.lngLat)
          .setHTML('<div class="map-popup-status-message">Laden...</div>')
          .addTo(self.map);

        if (shapeData && shapeData.resource_type) {
          var popupDataUrl = App.MapPopup.getPopupDataUrl(shapeData.resource_type, shapeData);

          if (popupDataUrl) {
            $.ajax(popupDataUrl, {
              type: "GET",
              dataType: "json"
            })
              .then(function(data) {
                var isInModal = !!self.element.dataset.modalMap;
                popup.setHTML(App.MapPopup.generatePopupContent(data, shapeData.resource_type, isInModal));
              })
          }

        }
      }
    }

    renderAdminShape() {
      if (this.adminShape && this.showAdminShape) {
        if (App.Map.validCoordinates(this.adminShape)) {
          if (this.adminEditor) {
            // Use the same approach as non-admin mode but make it draggable
            var styledMarker = this.getStyledMarker(this.adminShapesColor, this.adminShape.fa_icon_class);
            this.adminMarker = new mapboxgl.Marker({
              element: styledMarker.element,
              anchor: 'bottom',
              offset: [0, -10],
              draggable: true  // Make it draggable in admin editor mode
            })
              .setLngLat([this.adminShape.long, this.adminShape.lat])
              .setPopup(new mapboxgl.Popup().setHTML(App.MapPopup.adminShapePopupHtml()))
              .addTo(this.map);

            // Add drag event handler for form updates
            var self = this;
            this.adminMarker.on("dragend", function(e) {
              var marker = e.target;
              var lngLat = marker.getLngLat();
              $(self.latitudeInputSelector).val(lngLat.lat);
              $(self.longitudeInputSelector).val(lngLat.lng);
              $(self.altitudeInputSelector).val(0);
              $(self.zoomInputSelector).val(self.map.getZoom());
              if (self.showAdminShapeInputSelector) {
                $(self.showAdminShapeInputSelector).val(true);
              }
            });

          } else {
            var styledMarker = this.getStyledMarker(this.adminShapesColor, this.adminShape.fa_icon_class);
            this.adminMarker = new mapboxgl.Marker({
              element: styledMarker.element,
              anchor: 'bottom',
              offset: [0, -10]
            })
              .setLngLat([this.adminShape.long, this.adminShape.lat])
              .setPopup(new mapboxgl.Popup().setHTML(App.MapPopup.adminShapePopupHtml()))
              .addTo(this.map);
          }
        } else if (Object.keys(this.adminShape).length > 0) {
          this.renderMultishapeAdminLayer('admin-shape', this.adminShape, this.adminShapesColor);
        }
      }
    }

    renderMarkerCoordinates() {
      console.log("this.markerCoordinates", this.markerCoordinates)
      if (!this.markerCoordinates) return;

      if (this.adminEditor && this.setAdminCenterWithMarker) {
        this.centerMarker = this.createCenterMarker(this.markerCoordinates[0].lat, this.markerCoordinates[0].long);
      }
      else {
        this.addMarkersSource(this.createMarkersGeoJSON());
        this.addClusterLayers();
        this.addMarkerBackgroundLayer();
        this.loadMarkerImagesAndSetupIcons();
        // this.setupClusterEventListeners();
      }
    }

    createMarkersGeoJSON() {
      var features = [];
      var self = this;

      this.markerCoordinates.forEach(function(coordinate) {
        if (App.Map.validCoordinates(coordinate)) {
          // Regular point marker
          features.push({
            type: 'Feature',
            id: coordinate.id,
            geometry: {
              type: 'Point',
              coordinates: [parseFloat(coordinate.long), parseFloat(coordinate.lat)]
            },
            properties: {
              id: coordinate.id,
              resource_type: coordinate.resource_type,
              projekt_phase_id: coordinate.projekt_phase_id,
              color: coordinate.color,
              fa_icon_class: `fa-${coordinate.fa_icon_class}`
            }
          });
        // } else if (coordinate.features && Array.isArray(coordinate.features) && coordinate.type === "FeatureCollection") {
        } else if (coordinate.features && Array.isArray(coordinate.features)) {
          // // Handle other coordinate structures that might represent shapes
        }
      });

      return {
        type: 'FeatureCollection',
        features: features
      };
    }

    addMarkersSource(markersGeoJSON) {
      this.map.addSource('marker-coordinates', {
        type: 'geojson',
        data: markersGeoJSON,
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50
      });
    }

    addClusterLayers() {
      var clusterColor = this.getClusterColor();

      // Add cluster layer
      this.map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'marker-coordinates',
        filter: ['has', 'point_count'],
        paint: {
          'circle-color': [
            'step',
            ['get', 'point_count'],
            clusterColor,   // small clusters (e.g. < 10)
            10, clusterColor, // medium clusters (e.g. < 30)
            30, clusterColor  // large clusters (30+)
          ],
          'circle-radius': [
            'step',
            ['get', 'point_count'],
            18,
            10,
            22,
            28,
            25
          ]
        }
      });

      // Add cluster count layer
      this.map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'marker-coordinates',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': '{point_count_abbreviated}',
          'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
          'text-size': 17
        },
        paint: {
          'text-color': 'white'
        }
      });
    }

    getClusterColor() {
      var brandColor = getComputedStyle(document.documentElement)
        .getPropertyValue('--brand-color').trim() || '#004a83';
      return hexToRgba(brandColor, 0.5);
    }

    addMarkerBackgroundLayer() {
      var self = this;

      // Background layer for regular markers - add on top of shape layers
      this.map.addLayer({
        id: 'custom-marker',
        type: 'circle',
        source: 'marker-coordinates',
        filter: [
          'all',
          ['!', ['has', 'point_count']]
        ],
        paint: {
          'circle-color': ['coalesce', ['get', 'color'], App.Utils.getBrandColor()],
          'circle-radius': [
            'case',
            ['boolean', ['feature-state', 'hover'], false],
            self.defaultMarkerBackgroundCircleRadius + 1,
            self.defaultMarkerBackgroundCircleRadius
          ],
          'circle-stroke-width': 3,
          'circle-stroke-color': '#ffffff'
        }
      });
    }

    loadMarkerImagesAndSetupIcons() {
      if (this.markerImages && this.markerImages.length) {
        this.loadMarkerImages(() => {
          this.loadIconLayer();
        });
      } else {
        this.loadIconLayer();
      }
    }

    loadMarkerImages(callback) {
      var self = this;
      var loadedImages = 0;
      var totalImages = this.markerImages.length;

      this.markerImages.forEach(function(markerImage) {
        self.map.loadImage(markerImage.path, function(error, image) {
          if (error) {
            console.error('Error loading marker image:', error, markerImage);
          } else {
            self.map.addImage(markerImage.name, image, {sdf: true});
          }

          loadedImages++;
          if (loadedImages === totalImages) {
            callback();
          }
        });
      });
    }

    setupClusterEventListeners() {
      if (!this.editable) {
        // Only add hover events for clusters - clicks handled by unified handler
        this.map.on('mouseenter', 'clusters', () => {
          self.map.getCanvas().style.cursor = 'pointer';
        });
        this.map.on('mouseleave', 'clusters', () => {
          self.map.getCanvas().style.cursor = '';
        });
      }
    }

    renderResourceShapes() {
      var self = this;

      if (!this.editable) {
        this.markerCoordinates.forEach(function(coordinates) {
          if (!App.Map.validCoordinates(coordinates)) {
            self.renderShape(coordinates);
          }
        });
      }
    }

    renderWmsLayers() {
      if (this.layersData && typeof this.layersData !== "undefined") {
        try {
          var layersData = typeof this.layersData === 'string' ? JSON.parse(this.layersData) : this.layersData;

          if (Array.isArray(layersData) && layersData.length > 0) {
            layersData.forEach((layerData, index) =>  {
              this.createWmsLayers(layerData, index)
            });
          }
        } catch (error) {
          console.error('Error parsing layers data:', error, this.layersData);
        }
      }
    }

    // ensureBaseLayerVisibility() {
    //   var baseLayerKeys = Object.keys(this.baseLayers);
    //   if (baseLayerKeys.length > 0) {
    //     // Make the first base layer visible
    //     var firstBaseLayer = this.baseLayers[baseLayerKeys[0]];
    //     this.map.setLayoutProperty(firstBaseLayer.layerId, 'visibility', 'visible');
    //   }
    // }

    // showDefaultOverlayLayers() {
    //   Object.values(this.overlayLayers).forEach(layer => {
    //     if (layer.layerData.show_by_default) {
    //       this.map.setLayoutProperty(layer.layerId, 'visibility', 'visible');
    //     }
    //   });
    // }

    addLayerControl() {
      if (this.element.offsetWidth <= 780) {
        return;
      }

      // Always show layer control since it now includes POI labels
      this.map.addControl(new LayerControl(this), 'top-right');
    }

    toggleLayerVisibility(layerId, visible) {
      if (!this.mapLoaded) {
        this.map.once('idle', () => {
          this.toggleLayerVisibility(layerId, visible);
        });
        return;
      }

      if (this.map.getLayer(layerId)) {
        this.map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
      } else {
        console.error('Layer not found:', layerId);
      }
    }

    toggleAdminShapeVisibility(visible) {
      if (!this.mapLoaded) {
        this.map.once('idle', () => {
          this.toggleAdminShapeVisibility(visible);
        });
        return;
      }

      var adminLayerIds = [
        'admin-shape-layer',
        'admin-shape-border',
        'admin-shape-multipolygon-layer',
        'admin-shape-multipolygon-border',
        'admin-shape-points'
      ];

      adminLayerIds.forEach(layerId => {
        if (this.map.getLayer(layerId)) {
          this.map.setLayoutProperty(layerId, 'visibility', visible ? 'visible' : 'none');
        }
      });
    }

    createWmsLayers(layerData, index) {
      var sourceId = `layer-source-${index}`;
      var layerId = `layer-${index}`;

      try {
        if (layerData.protocol == 'wms') {
          // Build WMS URL properly following Mapbox GL JS format
          var baseUrl = layerData.provider;
          var separator = baseUrl.includes('?') ? '&' : '?';

          // Validate required parameters
          if (!layerData.layer_names || layerData.layer_names.trim() === '') {
            return;
          }

          // Build WMS URL following the official Mapbox example format
          // Use lowercase parameter names and don't URL-encode LAYERS
          var wmsParams = [
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

          var wmsUrl = baseUrl + separator + wmsParams.join('&');

          // Add WMS source
          this.map.addSource(sourceId, {
            type: 'raster',
            tiles: [wmsUrl],
            tileSize: 256
          });
        } else {
          // Add regular tile source
          this.map.addSource(sourceId, {
            type: 'raster',
            tiles: [layerData.provider],
            tileSize: 256
          });
        }

        // Add raster layer
        this.map.addLayer({
          id: layerId,
          type: 'raster',
          source: sourceId,
          paint: {
            'raster-opacity': parseFloat(layerData.opacity) || 1
          },
          layout: {
            'visibility': (layerData.show_by_default) ? 'visible' : 'none'
          }
        });

        // Store layer info for potential controls
        if (layerData.base) {
          this.baseLayers[layerData.name] = { sourceId, layerId, layerData };
        } else {
          this.overlayLayers[layerData.name] = { sourceId, layerId, layerData };
        }
      } catch (error) {
        console.error('Error creating layer:', error, layerData);
      }
    }


    loadIconLayer(e) {
      // Remove existing layer if it exists
      if (this.map.getLayer('custom-marker-icon')) {
        this.map.removeLayer('custom-marker-icon');
      }

      // Add icon layer on top of all other layers to ensure click priority
      this.map.addLayer({
        id: 'custom-marker-icon',
        type: 'symbol',
        source: 'marker-coordinates',
        filter: [
          'all',
          ['!', ['has', 'point_count']],
          ['has', 'fa_icon_class'],
          ['!=', ['get', 'fa_icon_class'], ''],
          ['!=', ['get', 'fa_icon_class'], null]
        ],
        layout: {
          'icon-image': ['get', 'fa_icon_class'],
          'icon-size': 0.35,
          'icon-allow-overlap': true,
          'icon-ignore-placement': true,
          'icon-anchor': 'center',
        },
        paint: {
          'icon-color': '#ffffff'
        }
      });

      this.setupMarkerEventListeners(e);
    }

    setupMarkerEventListeners() {
      this.map.on('mouseenter', 'custom-marker',
        this.handleMarkerMouseEnter.bind(this)
      );
      this.map.on('mouseleave', 'custom-marker',
        this.handleMarkerMouseLeave.bind(this)
      );

      // Only add popup handlers when NOT in edit mode
      if (!this.editable) {
        // Consolidated popup handler for all interactive layers
        this.map.on('click', (e) => {
          this.handleUnifiedPopup(e);
        });
        this.map.on('touchend', (e) => {
          this.handleUnifiedPopup(e);
        });
      }
    }

    handleMarkerMouseEnter(e) {
      this.map.getCanvas().style.cursor = 'pointer';

      if (e.features.length > 0) {
        if (this.hoveredFeature !== null) {
          this.map.setFeatureState(
            { source: 'marker-coordinates', id: this.hoveredFeature },
            { hover: false }
          );
        }
        this.hoveredFeature = e.features[0].id;
        this.map.setFeatureState(
          { source: 'marker-coordinates', id: this.hoveredFeature },
          { hover: true }
        );
      }
    };

    handleMarkerMouseLeave() {
      this.map.getCanvas().style.cursor = '';

      if (this.hoveredFeature !== null) {
        this.map.setFeatureState(
          { source: 'marker-coordinates', id: this.hoveredFeature },
          { hover: false }
        );
      }
      this.hoveredFeature = null;
    }

    renderShape(coordinates) {
      var self = this;
      // Generate a unique ID if coordinates.id is undefined
      var shapeId = coordinates.id || 'shape-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
      var sourceId = 'user-shape-' + shapeId;
      var layerId = 'user-shape-layer-' + shapeId;
      var borderLayerId = 'user-shape-border-' + shapeId;

      // Check if source already exists to prevent duplicate source error
      if (this.map.getSource(sourceId)) {
        return;
      }

      this.map.addSource(sourceId, {
        type: 'geojson',
        data: coordinates
      });

      const shapeColor = coordinates.color || App.Utils.getBrandColor();

      // Add fill layer
      this.map.addLayer({
        id: layerId,
        type: 'fill',
        source: sourceId,
        paint: {
          'fill-color': shapeColor,
          'fill-opacity': 0.2
        }
      });

      // Add border layer
      this.map.addLayer({
        id: borderLayerId,
        type: 'line',
        source: sourceId,
        paint: {
          'line-color': shapeColor,
          'line-width': 2,
          'line-opacity': 0.8
        }
      });

      // Create shared event handlers for hover only
      var setCursorPointer = function() {
        self.map.getCanvas().style.cursor = 'pointer';
      };
      var resetCursor = function() {
        self.map.getCanvas().style.cursor = '';
      };

      // Add event listeners for both fill and border layers (hover only)
      var layers = [layerId, borderLayerId];
      layers.forEach(function(layer) {
        // Desktop hover events only - clicks handled by unified handler
        self.map.on('mouseenter', layer, setCursorPointer);
        self.map.on('mouseleave', layer, resetCursor);
      });
    }

    renderMultishapeAdminLayer(id, data, color) {
      var self = this;

      this.map.addSource(id, {
        type: 'geojson',
        data: data
      });

      // Define layer configurations
      var layerConfigs = [
        {
          type: 'Polygon',
          layers: [
            {
              id: id + '-layer',
              type: 'fill',
              paint: {
                'fill-color': color, 'fill-opacity': this.saturatedAdminShape ? 0.22 : 0.15 }
            },
            {
              id: id + '-border',
              type: 'line',
              paint: { 'line-color': color, 'line-width': 2, 'line-opacity': 0.2 }
            }
          ]
        },
        {
          type: 'MultiPolygon',
          layers: [
            { id: id + '-multipolygon-layer', type: 'fill', paint: { 'fill-color': color, 'fill-opacity': 0.1 } },
            { id: id + '-multipolygon-border', type: 'line', paint: { 'line-color': color, 'line-width': 2, 'line-opacity': 0.2 } }
          ]
        },
        {
          type: 'Point',
          layers: [
            { id: id + '-points', type: 'circle', paint: { 'circle-color': color, 'circle-radius': (self.defaultMarkerBackgroundCircleRadius - 3), 'circle-stroke-width': 2, 'circle-stroke-color': '#ffffff' } }
          ]
        }
      ];

      var allLayers = [];
      layerConfigs.forEach((config) => {
        var hasGeometryType = self.hasGeometryType(data, config.type);
        if (hasGeometryType) {
          config.layers.forEach(function(layerConfig) {
            self.map.addLayer({
              id: layerConfig.id,
              type: layerConfig.type,
              source: id,
              filter: ['==', '$type', config.type],
              paint: layerConfig.paint
            });
            allLayers.push(layerConfig.id);
          });
        }
      });

      var setCursorPointer = function() { self.map.getCanvas().style.cursor = 'pointer'; };
      var resetCursor = function() { self.map.getCanvas().style.cursor = ''; };

      // Only add hover events - clicks handled by unified handler
      allLayers.forEach(function(layer) {
        self.map.on('mouseenter', layer, setCursorPointer);
        self.map.on('mouseleave', layer, resetCursor);
      });
    }

    // Helper method to check if data contains a specific geometry type
    hasGeometryType(data, geometryType) {
      if (data.features && Array.isArray(data.features)) {
        return data.features.some(function(feature) {
          return feature.geometry && feature.geometry.type === geometryType;
        });
      } else if (data.type === 'Feature') {
        return data.geometry && data.geometry.type === geometryType;
      } else if (data.type === geometryType) {
        return true;
      }
      return false;
    };

      // Add a method to clean up marker-coordinates
    destroy() {
      if (!this.map) return; // Early return if map is already destroyed

      try {
        // If map is still loading, wait for it to finish before destroying
        if (!this.mapLoaded && this.map.isStyleLoaded && !this.map.isStyleLoaded()) {
          this.map.once('idle', () => {
            this.performDestroy();
          });
          return;
        }

        this.performDestroy();
      } catch (e) {
        this.forceCleanup();
      }
    }

    performDestroy() {
      try {
        this.map.off();
        this.map.remove();
      } catch (e) {
        console.error('Error during map destruction:', e);
        this.forceCleanup();
      }
    }

   forceCleanup() {
      this.map = null;
      this.draw = null;
      // this.pinMarkers = [];
      this.adminMarker = null;
      this.centerMarker = null;
      this.mapLoaded = false;
      this.baseLayers = {};
      this.overlayLayers = {};
    }
  }

  function hexToRgba(hex, alpha) {
    // Remove # if present
    hex = hex.replace('#', '');

    // Parse RGB values
    var r = parseInt(hex.substring(0, 2), 16);
    var g = parseInt(hex.substring(2, 4), 16);
    var b = parseInt(hex.substring(4, 6), 16);

    return 'rgba(' + r + ', ' + g + ', ' + b + ', ' + alpha + ')';
  }

  class CustomDeleteControl {
    constructor(mapboxMapInstance) {
      this.mapboxMapInstance = mapboxMapInstance;
    }

    onAdd(map) {
      this._map = map;
      this._container = document.createElement('div');
      this._container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group';

      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-custom-delete-button';
      button.innerHTML = '<i class="fas fa-eraser"></i>';
      button.title = 'Alle Formen löschen';

      // Add click event listener
      button.addEventListener('click', () => {
        // Delete all draw features (polygons, lines, points from draw tools)
        if (this.mapboxMapInstance.draw) {
          this.mapboxMapInstance.draw.deleteAll();
          this.mapboxMapInstance.updateShapeFormFields();
        }

        // Delete all user markers (pin markers and editable marker)
        this.mapboxMapInstance.deleteAllUserMarkers();
      });

      this._container.appendChild(button);
      return this._container;
    }

    onRemove() {
      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
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
      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-layer-control-button';
      button.innerHTML = '<i class="fas fa-layer-group"></i>'; // Layers icon
      button.title = 'Kartenebenen';

      // Create dropdown container
      var dropdown = document.createElement('div');
      dropdown.className = 'mapbox-layer-control-dropdown';
      dropdown.style.display = 'none';

      // Add POI labels section
      var dropdownList = document.createElement('div');
      dropdownList.className = 'mapbox-layer-select-section';

      var dropdownTitle = document.createElement('div');
      dropdownTitle.className = 'mapbox-layer-select-section-title';
      dropdownTitle.textContent = 'Kartenebenen';
      dropdownList.appendChild(dropdownTitle);

      var poiLabel = this.createPoiCheckbox();
      dropdownList.appendChild(poiLabel);

      var adminShapeLabel = this.createAdminShapeCheckbox();
      dropdownList.appendChild(adminShapeLabel);

      dropdown.appendChild(dropdownList);

      // Add base layers section if any
      if (Object.keys(this.mapboxMapInstance.baseLayers).length > 0) {
        Object.entries(this.mapboxMapInstance.baseLayers).forEach(([name, layer], index) => {
          // Only the first base layer should be checked initially
          var isVisible = index === 0;
          var label = this.createLayerCheckbox(name, layer.layerId, isVisible, 'radio');
          dropdownList.appendChild(label);
        });
      }

      // Add overlay layers section if any
      if (Object.keys(this.mapboxMapInstance.overlayLayers).length > 0) {
        Object.entries(this.mapboxMapInstance.overlayLayers).forEach(([name, layer]) => {
          var isVisible = layer.layerData.show_by_default;
          var label = this.createLayerCheckbox(name, layer.layerId, isVisible, 'checkbox');
          dropdownList.appendChild(label);
        });
      }

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
      var label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      var input = document.createElement('input');
      input.type = inputType;
      input.checked = isChecked;
      if (inputType === 'radio') {
        input.name = 'base-layer';
      }

      var span = document.createElement('span');
      span.textContent = name;

      label.appendChild(input);
      label.appendChild(span);

             // Handle layer visibility changes
       input.addEventListener('change', () => {
         if (inputType === 'radio' && input.checked) {
           // For base layers (radio), hide all others and show selected
           Object.values(this.mapboxMapInstance.baseLayers).forEach(layer => {
             this.mapboxMapInstance.toggleLayerVisibility(layer.layerId, false);
           });
           this.mapboxMapInstance.toggleLayerVisibility(layerId, true);
         } else if (inputType === 'checkbox') {
           // For overlay layers (checkbox), toggle individual layer
           this.mapboxMapInstance.toggleLayerVisibility(layerId, input.checked);
         }
       });

      return label;
    }

    createPoiCheckbox() {
      var label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      var input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = true; // Default to on

      var span = document.createElement('span');
      span.textContent = 'Orte von Interesse';

      label.appendChild(input);
      label.appendChild(span);

      // Handle POI labels visibility changes
      input.addEventListener('change', () => {
        this.mapboxMapInstance.togglePoiLabels(input.checked);
      });

      return label;
    }

    createAdminShapeCheckbox() {
      var label = document.createElement('label');
      label.className = 'mapbox-layer-checkbox-label';

      var input = document.createElement('input');
      input.type = 'checkbox';
      input.checked = true; // Default to on (show admin shapes by default)

      var span = document.createElement('span');
      span.textContent = 'Verwaltungseinträge';

      label.appendChild(input);
      label.appendChild(span);

      // Handle admin shapes visibility changes
      input.addEventListener('change', () => {
        this.mapboxMapInstance.toggleAdminShapeVisibility(input.checked);
      });

      return label;
    }

    onRemove() {
      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
    }
  }

  // Custom control for fullscreen modal functionality
  class FullscreenModalControl {
    constructor(mapboxMapInstance) {
      this.mapboxMapInstance = mapboxMapInstance;
      this.modalId = 'mapbox-fullscreen-modal-' + Date.now();
      this.modalMapInstance = null;
      this.escHandler = null;
      this.isInModal = false;
    }

    onAdd(map) {
      this._map = map;
      this._container = document.createElement('div');
      this._container.className = 'mapboxgl-ctrl mapboxgl-ctrl-group';

      var button = document.createElement('button');
      button.type = 'button';
      button.className = 'mapbox-fullscreen-modal-button';
      button.innerHTML = '<i class="fas fa-expand"></i>';
      button.title = 'Vollbild-Modus';

      // Add click event listener
      button.addEventListener('click', () => {
        this.openModal();
      });

      this._container.appendChild(button);
      return this._container;
    }

    onRemove() {
      this.closeModal();

      if (this.escHandler) {
        document.removeEventListener('keydown', this.escHandler);
        this.escHandler = null;
      }

      this._container.parentNode.removeChild(this._container);
      this._map = undefined;
    }

    openModal() {
      if (this.isInModal) return;

      // Create modal HTML structure
      this.createModalStructure();

      // Initialize new map in modal container
      this.initializeModalMap();

      // Open Foundation reveal modal
      this.showFoundationModal();

      this.isInModal = true;
    }

    createModalStructure() {
      // Create modal container
      var modalHtml = `
        <div class="reveal map-modal" id="${this.modalId}" data-reveal data-close-on-click="true" data-close-on-esc="true">
          <button class="map-modal--close-button" data-close aria-label="Modal schließen" type="button">
            <span aria-hidden="true">&times;</span>
          </button>
          <div id="${this.modalId}-map-container" style="width: 100%; height: 100%;"></div>
        </div>
      `;

      document.body.insertAdjacentHTML('beforeend', modalHtml);

      var modal = document.getElementById(this.modalId);

      $(modal).on('closed.zf.reveal', () => {
        this.closeModal();
      });

      var closeButton = modal.querySelector('.map-modal--close-button');
      if (closeButton) {
        closeButton.addEventListener('click', () => { this.closeModal()});
      }

      // ESC key handler
      var escHandler = function(e) {
        if (e.key === 'Escape' && this.isInModal) {
          this.closeModal();
          document.removeEventListener('keydown', escHandler);
        }
      };
      document.addEventListener('keydown', escHandler);

      // Store escape handler reference for cleanup
      this.escHandler = escHandler;
    }

    initializeModalMap() {
      var modalContainer = document.getElementById(this.modalId + '-map-container');

      // Copy all data attributes from original map element
      this.copyDataAttributes(this.mapboxMapInstance.element, modalContainer);

      // Mark this as a modal map to prevent adding fullscreen control
      modalContainer.setAttribute('data-modal-map', 'true');

      // Get current map state from original map
      var center = this._map.getCenter();
      var zoom = this._map.getZoom();
      var bearing = this._map.getBearing();
      var pitch = this._map.getPitch();

      // Override center and zoom with current values
      modalContainer.setAttribute('data-map-center-latitude', center.lat);
      modalContainer.setAttribute('data-map-center-longitude', center.lng);
      modalContainer.setAttribute('data-map-zoom', zoom);

      // Wait for modal to be fully rendered before initializing map
      setTimeout(() => {
        // Initialize new MapboxMap instance in modal
        this.modalMapInstance = new MapboxMapController(modalContainer);

        // Apply current view state after map loads
        this.modalMapInstance.map.on('load', () => {
          this.modalMapInstance.map.setCenter(center);
          this.modalMapInstance.map.setZoom(zoom);
          this.modalMapInstance.map.setBearing(bearing);
          this.modalMapInstance.map.setPitch(pitch);
        });
      }, 100);
    }

    copyDataAttributes(sourceElement, targetElement) {
      // Get all data attributes from source element
      var dataset = sourceElement.dataset;

      // Copy each data attribute to target element
      for (var key in dataset) {
        if (dataset.hasOwnProperty(key)) {
          targetElement.setAttribute('data-' + this.camelToKebab(key), dataset[key]);
        }
      }
    }

    camelToKebab(str) {
      return str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase();
    }

    showFoundationModal() {
      // Initialize and open Foundation reveal modal
      var modal = new Foundation.Reveal($('#' + this.modalId));
      modal.open();
    }

    closeModal() {
      if (!this.isInModal) return;

      try {
        this.isInModal = false;

        if (this.modalMapInstance) {
          if (this.modalMapInstance.map) {
            this.modalMapInstance.map.off();
            this.modalMapInstance.map.remove();
          }
        }

        if (this.escHandler) {
          document.removeEventListener('keydown', this.escHandler);
          this.escHandler = null;
        }

        // Clean up modal HTML with delay to allow any pending operations
        setTimeout(() => {
          var modalElement = document.getElementById(this.modalId);
          if (modalElement) {
            modalElement.remove();
          }
        }, 50);

      } catch (e) {
        this.modalMapInstance = null;
        this.isInModal = false;
      }
    }

    // Public interface method for external use
    setMarkerTo(lat, lng) {
      // TODO
      // if (this.centerMarker) {
      //   this.centerMarker.setLatLng([lat, lng]);
      // } else {
      //   this.centerMarker = this.createMarker(lat, lng);
      // }
      // this.updateCenterMarkerFormFields();
    }
  }

  App.MapboxMapController = MapboxMapController;
}).call(this);

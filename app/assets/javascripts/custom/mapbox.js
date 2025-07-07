(function() {
  "use strict";

  // MapboxMap class definition
  function MapboxMap(element) {
    this.element = element;
    var $element = $(element);

    this.mapCenterLatitude = $element.data("map-center-latitude");
    this.mapCenterLongitude = $element.data("map-center-longitude");
    this.zoom = $element.data("map-zoom");
    this.resourcesName = $element.data("parent-class");
    this.markerCoordinates = $element.data("process-coordinates");
    this.editable = $element.data("editable");
    this.adminEditor = $element.data("admin-editor");
    this.adminShape = $element.data("admin-shape");
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

    this.map = null;
    this.pinMarkers = []; // Array to store all marker-coordinates
    this.adminMarker = null;
    this.editableMarker = null; // Single editable marker for user interaction
    this.markerCategoryIcon = null;
    this.markerCategoryColor = null;
    this.adminShapesColor = 'red';
    this.defaultMarkerBackgroundCircleRadius = 14;
    this.hoveredFeature = null;
    this.draw = null; // Mapbox Draw instance for polygon editing

    this.initialize();
  }

  MapboxMap.prototype.initialize = function() {
    var self = this;

    this.map = this.initializeMap();
    this.mapLoaded = false; // Track map loading state

    // Wait for the map to load before adding marker-coordinates
    this.map.on('load', function() {
      self.mapLoaded = true;

      self.renderAdminShape();

      self.renderMarkerCoordinates();
      self.renderResourceShapes();
      self.addMapInstructionOverlay();
    });

    this.setupEventListeners();
    this.addControls();
  };

  MapboxMap.prototype.initializeMap = function() {
    var self = this;
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

    // console.log("Using style", this.styleId)

    return new mapboxgl.Map(mapSettings);
  };

  MapboxMap.prototype.setupEventListeners = function() {
    var self = this;

    if (this.$categorySelect) {
      this.$categorySelect.on("change", function(e) {
        self.updateMarkerStyleFromCategorySelect(e.target);
      });

      if (this.$categorySelect.length) {
        this.updateMarkerStyleFromCategorySelect(this.$categorySelect.get(0));
      }
    }

    if (this.adminEditor && !this.pinMarkers.length) {
      this.map.on("moveend", function() {
        var center = self.map.getCenter();
        $(self.latitudeInputSelector).val(center.lat);
        $(self.longitudeInputSelector).val(center.lng);
        $(self.altitudeInputSelector).val(0); // Set altitude to 0 for map center updates
        $(self.zoomInputSelector).val(self.map.getZoom());
      });
    }

    // Add click and touch listeners for moveOrPlaceMarker functionality
    if (this.editable) {
      // Handle both click and touch events for better mobile support
      var handleMapInteraction = function(e) {
        // Check if interaction is on a draw control button
        var target = e.originalEvent ? e.originalEvent.target : e.target;
        var isDrawControl = target && (
          target.classList.contains('mapbox-gl-draw_ctrl-draw-btn') ||
          target.closest('.mapbox-gl-draw_ctrl')
        );

        // Only handle interactions that aren't on existing marker-coordinates/features or draw controls
        var features = self.map.queryRenderedFeatures(e.point, {
          layers: ['custom-marker', 'custom-marker-icon', 'clusters']
        });

        // Check current draw mode
        var currentMode = 'simple_select';
        if (self.draw) {
          currentMode = self.draw.getMode();
        }

        var drawFetures = self.draw.getAll().features;

        // Check if there are existing draw features
        var hasExistingDrawFeatures = self.draw && drawFetures.length > 0;
        var hasOnlyPointDrawFeatures = drawFetures.length === 1 && drawFetures[0].geometry.type.toLowerCase() === "point"

        // Place editable marker if:
        // - No features clicked
        // - Not clicked on draw controls
        // - No existing draw features (to avoid conflicts)
        // Allow placing marker-coordinates even in drawing modes for better UX

        if (hasOnlyPointDrawFeatures || (features.length === 0 && !isDrawControl && !hasExistingDrawFeatures)) {
          self.moveOrPlaceMarker(e);
        }
      };

      // Add both click and touch event listeners
      this.map.on('click', handleMapInteraction);
      this.map.on('touchend', handleMapInteraction);
    }
  };

  MapboxMap.prototype.addControls = function() {
    this.map.addControl(new mapboxgl.NavigationControl());

    this.map.addControl(new mapboxgl.GeolocateControl({
      positionOptions: {
        enableHighAccuracy: true
      },
      trackUserLocation: true
    }));

    if (this.editable && typeof MapboxDraw !== 'undefined') {
      this.initializePolygonEditor();
    }
  };

  MapboxMap.prototype.addMapInstructionOverlay = function() {
    var self = this;

    // Create overlay container
    var overlay = document.createElement('div');
    overlay.className = 'mapbox-instruction-overlay';
    overlay.innerHTML = '<span class="mapbox-instruction-text">Klicken Sie auf die Karte um Marker zu platzieren</span>';

    // Add CSS styles to match Mapbox attribution style
    overlay.style.cssText = `
      position: absolute;
      bottom: 0;
      left: 50%;
      transform: translateX(-50%);
      background: rgba(255, 255, 255, 0.5);
      color: rgba(0, 0, 0, 0.75);
      padding: 2px 6px;
      border-radius: 0;
      font-size: 12px;
      z-index: 100;
      transition: opacity 0.3s ease;
      opacity: 0.8;
      backdrop-filter: blur(2px);
      border-top: 1px solid rgba(0, 0, 0, 0.1);
    `;

    // Add overlay to map container
    this.element.style.position = 'relative';
    this.element.appendChild(overlay);

    // Store reference for cleanup
    this.instructionOverlay = overlay;
  };

  MapboxMap.prototype.getDrawStyles = function() {
    var color = this.markerCategoryColor || (this.adminEditor ? this.adminShapesColor : '#ff0000');
    const blue = '#3bb2d0';
    const orange = '#fbb03b';
    const white = '#fff';

    return [
      // // Bigger points
      // {
      //   'id': 'gl-draw-point-point-stroke-inactive',
      //   'type': 'circle',
      //   'filter': ['all', ['==', '$type', 'Point'], ['==', 'meta', 'feature'], ['!=', 'mode', 'static']],
      //   'paint': {
      //     'circle-radius': 10,
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
            blue,
          ],
          'fill-opacity': 0.3,
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
            blue,
          ],
          'line-dasharray': [
            'case',
            ['==', ['get', 'active'], 'true'], [0.2, 2],
            [2, 0],
          ],
          'line-width': 3,
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
            ['==', ['get', 'active'], 'true'], 7,
            5,
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
          'circle-radius': [
            'case',
            ['==', ['get', 'active'], 'true'], 5,
            3,
          ],
          'circle-color': [
            'case',
            ['==', ['get', 'active'], 'true'], orange,
            blue,
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
  };

  MapboxMap.prototype.initializePolygonEditor = function() {
    // Initialize Mapbox Draw with bigger point styles
    this.draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: {
        polygon: true,
        point: true,
        line_string: true,
        trash: true
      },
      defaultMode: 'simple_select', // Start in selection mode, not drawing mode
      styles: this.getDrawStyles()
    });

    // Add the draw control to the map
    this.map.addControl(this.draw);

    // Load existing shape data if available
    this.loadExistingShape();

    // Set up event listeners for draw events
    this.setupDrawEventListeners();
  };

  MapboxMap.prototype.loadExistingShape = function() {
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
  };

  MapboxMap.prototype.setupDrawEventListeners = function() {
    var self = this;

    // Update form fields when shapes are created, updated, or deleted
    this.map.on('draw.create', function(e) {
      // If not admin editor, ensure only one polygon exists
      if (!self.adminEditor) {
        var allFeatures = self.draw.getAll();
        // If we have more than one feature, remove all but the newest one
        if (allFeatures.features.length > 1) {
          // Get the newly created feature(s) from the event
          var newFeatureIds = e.features.map(function(feature) {
            return feature.id;
          });

          // Delete all features except the newly created ones
          var featuresToDelete = allFeatures.features.filter(function(feature) {
            return newFeatureIds.indexOf(feature.id) === -1;
          });

          var idsToDelete = featuresToDelete.map(function(feature) {
            return feature.id;
          });

          if (idsToDelete.length > 0) {
            self.draw.delete(idsToDelete);
          }
        }
      }

      self.updateShapeFormFields();
      // Remove any existing marker-coordinates when a shape is created
      self.removeEditableMarker();
    });

    this.map.on('draw.update', function(e) {
      self.updateShapeFormFields();
    });

    this.map.on('draw.delete', function(e) {
      self.updateShapeFormFields();
    });

    // Listen for mode changes to help with conflict resolution
    this.map.on('draw.modechange', function(e) {
      // console.log('Draw mode changed to:', e.mode);
      // If entering a drawing mode, clear any existing marker-coordinates
      if (e.mode.startsWith('draw_')) {
        self.removeEditableMarker();
      }
    });
  };

  MapboxMap.prototype.updateShapeFormFields = function() {
    if (!this.draw || !this.shapeInputSelector) return;

    var allFeatures = this.draw.getAll();

    // Update the shape input field with the current polygon data
    $(this.shapeInputSelector).val(JSON.stringify(allFeatures));

    // Clear coordinates if we have a polygon
    if (allFeatures.features.length > 0) {
      $(this.altitudeInputSelector).val(''); // Clear altitude when shape is present
    }

    // Update zoom
    $(this.zoomInputSelector).val(this.map.getZoom());

    if (this.adminEditor && this.showAdminShapeInputSelector) {
      $(this.showAdminShapeInputSelector).val(true);
    }
  };

  MapboxMap.prototype.getStyledMarker = function(color, iconClass) {
    if (this.markerCategoryIcon) {
      iconClass = this.markerCategoryIcon;
    } else if (!iconClass) {
      iconClass = 'circle';
    }

    if (this.markerCategoryColor) {
      color = this.markerCategoryColor;
    }

    if (this.adminEditor) {
      color = this.adminShapesColor;
    }

    return {
      element: this.createMarkerElement(color, iconClass),
      anchor: [0, 0]
    };
  };

  MapboxMap.prototype.createMarkerElement = function(color, iconClass) {
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

  MapboxMap.prototype.createPinMarker = function(latitude, longitude, color, iconClass) {
    var styledMarker = this.getStyledMarker(color, iconClass);
    var markerOptions = {
      element: styledMarker.element,
      anchor: 'bottom',
      offset: [0, -10],
      draggable: this.editable
    };

    var pinMarker = new mapboxgl.Marker(markerOptions)
      .setLngLat([longitude, latitude]);

    if (this.editable) {
      pinMarker.on("dragend", this.updateFormfieldsWithMarker.bind(this));
    }
    pinMarker.addTo(this.map);

    // Add pinMarker to our marker-coordinates array
    this.pinMarkers.push(pinMarker);

    return pinMarker;
  };

  MapboxMap.prototype.updateFormfieldsWithMarker = function(e) {
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
  };

  // Helper method to remove editable marker
  MapboxMap.prototype.removeEditableMarker = function() {
    if (this.editableMarker) {
      this.editableMarker.remove();
      this.editableMarker = null;
    }
  };

  // function to create or move existing marker (similar to Leaflet version)
  MapboxMap.prototype.moveOrPlaceMarker = function(e) {
    var self = this;
    var lngLat = e.lngLat;

    // console.log("moveOrPlaceMarker clicked at:", lngLat.lng, lngLat.lat);

    // Clear any existing draw features when placing an editable marker
    if (this.draw) {
      var allFeatures = this.draw.getAll();
      if (allFeatures.features.length > 0) {
        this.draw.deleteAll();
      }
      // Switch draw mode to simple_select to avoid conflicts
      this.draw.changeMode('simple_select');
    }

    // Move existing marker or create new one
    if (this.editableMarker) {
      this.editableMarker.setLngLat([lngLat.lng, lngLat.lat]);
      this.updateMarkerWithCategoryStyle();
    } else {
      this.editableMarker = this.createEditableMarker(lngLat.lat, lngLat.lng);
    }
    this.updateFormfieldsFromEditableMarker();
  };

  // function to update form fields when editable marker is updated
  MapboxMap.prototype.updateFormfieldsFromEditableMarker = function() {
    if (!this.editableMarker) return;

    var lngLat = this.editableMarker.getLngLat();
    // console.log("Updating form fields with coordinates:", lngLat.lat, lngLat.lng);

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
  MapboxMap.prototype.createEditableMarker = function(latitude, longitude) {
    var self = this;

    // console.log("Creating editable marker at:", latitude, longitude);

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

    marker.on("dragend", function() {
      self.updateFormfieldsFromEditableMarker();
    });

    marker.addTo(this.map);

    // console.log("Marker created at:", marker.getLngLat());

    return marker;
  };

  MapboxMap.prototype.updateMarkerStyleFromCategorySelect = function(element) {
    var selectedOption = element.options[element.selectedIndex];
    this.markerCategoryIcon = selectedOption.dataset.icon;
    this.markerCategoryColor = selectedOption.dataset.color;
    this.updateMarkerWithCategoryStyle();
  };

  MapboxMap.prototype.updateMarkerWithCategoryStyle = function() {
    if (this.pinMarkers.length) {
      this.pinMarkers.forEach(function(marker) {
        marker.setIcon(this.getStyledMarker(null, null));
      }.bind(this));
    }

    // Also update editable marker if it exists
    if (this.editableMarker) {
      var newIcon = this.getStyledMarker(null, null);
      this.editableMarker.getElement().innerHTML = '';
      this.editableMarker.getElement().appendChild(newIcon.element);
    }
  };

  MapboxMap.prototype.openMarkerPopup = function(e) {
    var self = this;

    // console.log("handle click on marker")

    // Check if we have features and at least one feature
    if (!e.features || !e.features.length || !e.features[0]) {
      console.warn("No features found in popup event:", e);
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
        popup.setHTML(App.MapPopup.generatePopupContent(data, resourceType));
      })
      .fail(function() {
        popup.setHTML('<div class="map-popup-status-message error">Failed to load data</div>');
      })
  };

  MapboxMap.prototype.renderAdminShape = function() {
    if (this.adminShape && this.showAdminShape) {
      if (App.Mapbox.validCoordinates(this.adminShape)) {
        if (this.adminEditor) {
          this.createPinMarker(
            this.adminShape.lat,
            this.adminShape.long,
            this.adminShapesColor,
            this.adminShape.fa_icon_class
          );
        } else {
          var styledMarker = this.getStyledMarker(this.adminShapesColor, this.adminShape.fa_icon_class);
          this.adminMarker = new mapboxgl.Marker({
            element: styledMarker.element,
            anchor: 'bottom',
            offset: [0, -10]
          })
            .setLngLat([this.adminShape.long, this.adminShape.lat])
            .setPopup(new mapboxgl.Popup().setHTML('Alle markierten Flächen und Pins in rot sind vom System vorgegeben'))
            .addTo(this.map);
        }
      } else if (Object.keys(this.adminShape).length > 0) {
        this.renderMultishapeAdminLayer('admin-shape', this.adminShape, this.adminShapesColor);
      }
    }
  };

  MapboxMap.prototype.renderMarkerCoordinates = function() {
    if (!this.markerCoordinates) return;

    var markersGeoJSON = this.createMarkersGeoJSON();
    this.addMarkersSource(markersGeoJSON);
    this.addClusterLayers();
    this.addMarkerBackgroundLayer();
    this.loadMarkerImagesAndSetupIcons();
    this.setupClusterEventListeners();
  };

  MapboxMap.prototype.createMarkersGeoJSON = function() {
    var features = [];
    var self = this;

    this.markerCoordinates.forEach(function(coordinate) {
      if (App.Mapbox.validCoordinates(coordinate)) {
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
            fa_icon_class: coordinate.fa_icon_class
          }
        });
      // } else if (coordinate.features && Array.isArray(coordinate.features) && coordinate.type === "FeatureCollection") {
      } else if (coordinate.features && Array.isArray(coordinate.features)) {
        // Handle other coordinate structures that might represent shapes
        coordinate.features.forEach(function(feature) {
            var centroid = calculatePolygonCentroid(feature.geometry);
            // console.log("render shape with polygon marker", coordinate)
            // console.log("centroid", centroid)

            if (centroid) {
              features.push({
                type: 'Feature',
                id: (coordinate.id || 'shape_' + Date.now()) + '_centroid',
                geometry: {
                  type: 'Point',
                  coordinates: centroid
                },
                properties: {
                  id: coordinate.id,
                  resource_type: coordinate.resource_type,
                  projekt_phase_id: coordinate.projekt_phase_id,
                  color: coordinate.color,
                  fa_icon_class: coordinate.fa_icon_class,
                  is_shape_centroid: true
                }
              });
            }
        })
      }
    });

    return {
      type: 'FeatureCollection',
      features: features
    };
  };

  MapboxMap.prototype.addMarkersSource = function(markersGeoJSON) {
    this.map.addSource('marker-coordinates', {
      type: 'geojson',
      data: markersGeoJSON,
      cluster: true,
      clusterMaxZoom: 14,
      clusterRadius: 50
    });
  };

  MapboxMap.prototype.addClusterLayers = function() {
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
  };

  MapboxMap.prototype.getClusterColor = function() {
    var brandColor = getComputedStyle(document.documentElement)
      .getPropertyValue('--brand-color').trim() || '#004a83';
    return hexToRgba(brandColor, 0.5);
  };

  MapboxMap.prototype.addMarkerBackgroundLayer = function() {
    var self = this;

    this.map.addLayer({
      id: 'custom-marker',
      type: 'circle',
      source: 'marker-coordinates',
      filter: [
        'all',
        ['!', ['has', 'is_shape_centroid']],
        ['!', ['has', 'point_count']]
      ],
      paint: {
        'circle-color': ['coalesce', ['get', 'color'], '#ff0000'],
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
  };

  MapboxMap.prototype.loadMarkerImagesAndSetupIcons = function() {
    var self = this;

    if (this.markerImages && this.markerImages.length) {
      this.loadMarkerImages(function() {
        self.renderIconLayer();
      });
    } else {
      this.renderIconLayer();
    }
  };

  MapboxMap.prototype.loadMarkerImages = function(callback) {
    var self = this;
    var loadedImages = 0;
    var totalImages = this.markerImages.length;

    this.markerImages.forEach(function(markerImage) {
      self.map.loadImage(markerImage.path, function(error, image) {
        if (error) {
          console.error('Error loading marker image:', error, markerImage);
        } else {
          self.map.addImage(markerImage.name, image);
        }

        loadedImages++;
        if (loadedImages === totalImages) {
          callback();
        }
      });
    });
  };

  MapboxMap.prototype.setupClusterEventListeners = function() {
    var self = this;

    // Handle cluster interactions (both click and touch)
    var handleClusterInteraction = function(e) {
      var features = self.map.queryRenderedFeatures(e.point, {
        layers: ['clusters']
      });
      var clusterId = features[0].properties.cluster_id;
      self.map.getSource('marker-coordinates').getClusterExpansionZoom(
        clusterId,
        function(err, zoom) {
          if (err) return;

          self.map.easeTo({
            center: features[0].geometry.coordinates,
            zoom: zoom
          });
        }
      );
    };

    // Add both click and touch event listeners for clusters
    this.map.on('click', 'clusters', handleClusterInteraction);
    this.map.on('touchend', 'clusters', handleClusterInteraction);

    // Add cursor pointer on hover (desktop only)
    this.map.on('mouseenter', 'clusters', function() {
      self.map.getCanvas().style.cursor = 'pointer';
    });
    this.map.on('mouseleave', 'clusters', function() {
      self.map.getCanvas().style.cursor = '';
    });
  };

  MapboxMap.prototype.renderResourceShapes = function() {
    var self = this;

    if (!this.editable) {
      this.markerCoordinates.forEach(function(coordinates) {
        if (!App.Mapbox.validCoordinates(coordinates)) {
          self.renderShape(coordinates);
        }
      });
    }
  };

  MapboxMap.prototype.renderIconLayer = function(e) {
    var self = this;

    // Remove existing layer if it exists
    if (self.map.getLayer('custom-marker-icon')) {
      self.map.removeLayer('custom-marker-icon');
    }

    // Add the unclustered point layer
    self.map.addLayer({
      id: 'custom-marker-icon',
      type: 'symbol',
      source: 'marker-coordinates',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': ['get', 'fa_icon_class'],
        'icon-size': [
          'case',
          ['boolean', ['get', 'is_shape_centroid'], false],
          0.4,  // 30% bigger for shape centroid icons (0.35 * 1.3)
          0.35    // Normal size for regular markers
        ],
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        'icon-anchor': 'center',
      }
    }, null);

    self.setupMarkerEventListeners(e);
  }

  MapboxMap.prototype.setupMarkerEventListeners = function() {
    var self = this;

    // Desktop hover events
    self.map.on('mouseenter', 'custom-marker',
      self.handleMarkerMouseEnter.bind(self)
    );
    self.map.on('mouseleave', 'custom-marker',
      self.handleMarkerMouseLeave.bind(self)
    );

    // Show popup on click and touch
    self.map.on('click', 'custom-marker',
      self.openMarkerPopup.bind(self)
    );
    self.map.on('touchend', 'custom-marker',
      self.openMarkerPopup.bind(self)
    );
  };

  MapboxMap.prototype.handleMarkerMouseEnter = function(e) {
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

  MapboxMap.prototype.handleMarkerMouseLeave = function() {
    this.map.getCanvas().style.cursor = '';

    if (this.hoveredFeature !== null) {
      this.map.setFeatureState(
        { source: 'marker-coordinates', id: this.hoveredFeature },
        { hover: false }
      );
    }
    this.hoveredFeature = null;
  };

  MapboxMap.prototype.renderShape = function(coordinates) {
    var self = this;
    // Generate a unique ID if coordinates.id is undefined
    var shapeId = coordinates.id || 'shape-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    var sourceId = 'user-shape-' + shapeId;
    var layerId = 'user-shape-layer-' + shapeId;
    var borderLayerId = 'user-shape-border-' + shapeId;

    // Check if source already exists to prevent duplicate source error
    if (this.map.getSource(sourceId)) {
      // console.warn('Source with ID', sourceId, 'already exists. Skipping...');
      return;
    }

    this.map.addSource(sourceId, {
      type: 'geojson',
      data: coordinates
    });

    // Add fill layer
    this.map.addLayer({
      id: layerId,
      type: 'fill',
      source: sourceId,
      paint: {
        'fill-color': coordinates.color,
        'fill-opacity': 0.2
      }
    });

    // Add border layer
    this.map.addLayer({
      id: borderLayerId,
      type: 'line',
      source: sourceId,
      paint: {
        'line-color': coordinates.color,
        'line-width': 2,
        'line-opacity': 0.8
      }
    });

    // Create shared event handlers
    var setCursorPointer = function() {
      self.map.getCanvas().style.cursor = 'pointer';
    };
    var resetCursor = function() {
      self.map.getCanvas().style.cursor = '';
    };
    var handleShapeInteraction = function(e) {
      // Create a proper event structure for the popup
      var popupEvent = {
        features: [{
          geometry: {
            coordinates: e.lngLat ? [e.lngLat.lng, e.lngLat.lat] : [0, 0]
          },
          properties: {
            id: coordinates.id || shapeId,
            resource_type: coordinates.resource_type || 'shape'
          }
        }]
      };

      self.openMarkerPopup(popupEvent);
    };

    // Add event listeners for both fill and border layers
    var layers = [layerId, borderLayerId];
    layers.forEach(function(layer) {
      // Desktop hover events
      self.map.on('mouseenter', layer, setCursorPointer);
      self.map.on('mouseleave', layer, resetCursor);

      // Click and touch events
      self.map.on('click', layer, handleShapeInteraction);
      self.map.on('touchend', layer, handleShapeInteraction);
    });
  };

  MapboxMap.prototype.renderMultishapeAdminLayer = function(id, data, color) {
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
          { id: id + '-layer', type: 'fill', paint: { 'fill-color': color, 'fill-opacity': 0.1 } },
          { id: id + '-border', type: 'line', paint: { 'line-color': color, 'line-width': 2, 'line-opacity': 0.2 } }
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

    // Add layers for each geometry type that exists in the data
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

    // Add event listeners
    var setCursorPointer = function() { self.map.getCanvas().style.cursor = 'pointer'; };
    var resetCursor = function() { self.map.getCanvas().style.cursor = ''; };

    allLayers.forEach(function(layer) {
      // Desktop hover events
      self.map.on('mouseenter', layer, setCursorPointer);
      self.map.on('mouseleave', layer, resetCursor);
    });

    if (!this.editable) {
      var handleAdminShapeInteraction = function() {
        new mapboxgl.Popup()
          .setLngLat(self.map.getCenter())
          .setHTML('<div class="map-popup-status-message error">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>')
          .addTo(self.map);
      };

      allLayers.forEach(function(layer) {
        // Click and touch events
        self.map.on('click', layer, handleAdminShapeInteraction);
        self.map.on('touchend', layer, handleAdminShapeInteraction);
      });
    }
  };

  // Helper method to check if data contains a specific geometry type
  MapboxMap.prototype.hasGeometryType = function(data, geometryType) {
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
  MapboxMap.prototype.destroy = function() {
    if (!this.map) return; // Early return if map is already destroyed

    var self = this;

    try {
      // If map is still loading, wait for it to finish before destroying
      if (!this.mapLoaded && this.map.isStyleLoaded && !this.map.isStyleLoaded()) {
        this.map.once('idle', function() {
          self.performDestroy();
        });
        return;
      }

      this.performDestroy();

    } catch (e) {
      console.error('Error during map destruction:', e);
      this.forceCleanup();
    }
  };

  // Separated destroy logic for better control
  MapboxMap.prototype.performDestroy = function() {
    var self = this;

    try {
      // Remove all event listeners first
      this.map.off();

      // Clean up instruction overlay
      if (this.instructionOverlay) {
        try {
          if (this.instructionOverlay.parentNode) {
            this.instructionOverlay.parentNode.removeChild(this.instructionOverlay);
          }
        } catch (e) {
          console.warn('Error removing instruction overlay:', e);
        }
        this.instructionOverlay = null;
      }

      // Clear overlay timeout
      if (this.overlayTimeout) {
        clearTimeout(this.overlayTimeout);
        this.overlayTimeout = null;
      }

      // Clean up draw instance
      if (this.draw) {
        try {
          this.map.removeControl(this.draw);
        } catch (e) {
          console.warn('Error removing draw control:', e);
        }
        this.draw = null;
      }

      // Clean up all marker-coordinates
      this.pinMarkers.forEach(function(marker) {
        try {
          marker.remove();
        } catch (e) {
          console.warn('Error removing marker:', e);
        }
      });
      this.pinMarkers = [];

      if (this.adminMarker) {
        try {
          this.adminMarker.remove();
        } catch (e) {
          console.warn('Error removing admin marker:', e);
        }
        this.adminMarker = null;
      }

      if (this.editableMarker) {
        try {
          this.editableMarker.remove();
        } catch (e) {
          console.warn('Error removing editable marker:', e);
        }
        this.editableMarker = null;
      }

      // Clean up any popups
      var popups = document.querySelectorAll('.mapboxgl-popup');
      popups.forEach(function(popup) {
        if (popup.parentNode) {
          popup.parentNode.removeChild(popup);
        }
      });

      // Remove sources and layers if they exist
      this.cleanupMapSources();

      // Wait a bit before removing the map to allow cleanup
      setTimeout(function() {
        if (self.map) {
          try {
            self.map.remove();
          } catch (e) {
            console.warn('Error removing map:', e);
          }
          self.map = null;
          self.mapLoaded = false;
        }
      }, 100);

    } catch (e) {
      console.error('Error during map destruction:', e);
      this.forceCleanup();
    }
  };

  // Clean up map sources and layers
  MapboxMap.prototype.cleanupMapSources = function() {
    if (!this.map || !this.mapLoaded) return;

    try {
      // Remove known sources
      var sources = ['marker-coordinates', 'admin-shape'];
      sources.forEach(function(sourceId) {
        if (this.map.getSource(sourceId)) {
          this.map.removeSource(sourceId);
        }
      }.bind(this));
    } catch (e) {
      console.warn('Error cleaning up map sources:', e);
    }
  };

  // Force cleanup when errors occur
  MapboxMap.prototype.forceCleanup = function() {
    this.map = null;
    this.draw = null;
    this.pinMarkers = [];
    this.adminMarker = null;
    this.editableMarker = null;
    this.mapLoaded = false;
  };

  // Convert hex color to RGBA with 50% opacity
  function hexToRgba(hex, alpha) {
    // Remove # if present
    hex = hex.replace('#', '');

    // Parse RGB values
    var r = parseInt(hex.substring(0, 2), 16);
    var g = parseInt(hex.substring(2, 4), 16);
    var b = parseInt(hex.substring(4, 6), 16);

    return 'rgba(' + r + ', ' + g + ', ' + b + ', ' + alpha + ')';
  }



  // Calculate centroid of a polygon
  function calculatePolygonCentroid(geometry) {
    // Handle different coordinate structures
    var coords;

    if (geometry.type === 'Polygon') {
      coords = geometry.coordinates[0]; // Get outer ring
    } else if (geometry.type === 'MultiPolygon') {
      coords = geometry.coordinates[0][0]; // Get first polygon's outer ring
    } else if (Array.isArray(geometry) && Array.isArray(geometry[0])) {
      coords = geometry;
    }

    if (!coords || coords.length === 0) {
      return null;
    }

    var x = 0, y = 0;
    var validCoords = coords.filter(function(coord) {
      return Array.isArray(coord) && coord.length >= 2 &&
             !isNaN(coord[0]) && !isNaN(coord[1]);
    });

    if (validCoords.length === 0) {
      return null;
    }

    validCoords.forEach(function(coord) {
      x += parseFloat(coord[0]);
      y += parseFloat(coord[1]);
    });

    return [x / validCoords.length, y / validCoords.length];
  }

  // Keep the existing App.Mapbox object
  App.Mapbox = {
    maps: [], // Store MapboxMap instances for proper cleanup
    initialize: function() {
      var self = this;
      $("[data-mapbox]").each(function() {
        var element = this;
        var mapInstance = self.initializeFor(element)

        self.maps.push(mapInstance);
      });
    },
    initializeFor: function(element) {
      return new MapboxMap(element);
    },
    destroy: function() {
      // Use the proper destroy method for MapboxMap instances
      this.maps.forEach(function(mapInstance) {
        try {
          mapInstance.destroy();
        } catch (e) {
          console.warn('Error destroying map instance:', e);
        }
      });

      this.maps = [];
    },
    validCoordinates: function(coordinates) {
      return !isNaN(parseFloat(coordinates.lat)) && !isNaN(parseFloat(coordinates.long));
    },
    isNumeric: function(n) {
      return !isNaN(parseFloat(n)) && isFinite(n);
    }
  };
}).call(this);

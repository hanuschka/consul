(function() {
  "use strict";

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

  // MapboxMap class definition
  function MapboxMap(element) {
    this.element = element;
    var $element = $(element);

    this.mapCenterLatitude = $element.data("map-center-latitude");
    this.mapCenterLongitude = $element.data("map-center-longitude");
    this.zoom = $element.data("map-zoom");
    this.resourcesName = $element.data("parent-class");
    this.processCoordinates = $element.data("process-coordinates");
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
    this.markers = []; // Array to store all markers
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
    this.initializeMap();
    this.setupEventListeners();
    this.addControls();
  };

  MapboxMap.prototype.initializeMap = function() {
    var self = this;
    mapboxgl.accessToken = this.element.dataset.mapboxPublicToken;

    this.map = new mapboxgl.Map({
      style: this.styleId,
      container: this.element,
      center: [this.mapCenterLongitude, this.mapCenterLatitude],
      zoom: this.zoom
    });

    // Wait for the map to load before adding markers
    this.map.on('load', function() {
      self.addMarkers();
    });

    App.Mapbox.maps.push(this.map);
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

    if (this.adminEditor && !this.markers.length) {
      this.map.on("moveend", function() {
        var center = self.map.getCenter();
        $(self.latitudeInputSelector).val(center.lat);
        $(self.longitudeInputSelector).val(center.lng);
        $(self.altitudeInputSelector).val(0); // Set altitude to 0 for map center updates
        $(self.zoomInputSelector).val(self.map.getZoom());
      });
    }

    // Add click listener for moveOrPlaceMarker functionality
    if (this.editable) {
      this.map.on('click', function(e) {
        // Check if click is on a draw control button
        var target = e.originalEvent.target;
        var isDrawControl = target && (
          target.classList.contains('mapbox-gl-draw_ctrl-draw-btn') ||
          target.closest('.mapbox-gl-draw_ctrl')
        );

        // Only handle clicks that aren't on existing markers/features or draw controls
        var features = self.map.queryRenderedFeatures(e.point, {
          layers: ['custom-marker', 'custom-marker-icon', 'clusters']
        });

        // Don't place markers if we're in drawing mode or clicked on draw controls
        var isDrawingMode = false;
        if (self.draw) {
          var currentMode = self.draw.getMode();
          isDrawingMode = currentMode.startsWith('draw_') || currentMode === 'direct_select';
        }

        // Only place markers if:
        // - No features clicked
        // - Not in drawing mode
        // - Not clicked on draw controls
        // - Draw has no existing features (to avoid conflicts)
        var hasExistingShapes = self.draw && self.draw.getAll().features.length > 0;

        if (features.length === 0 && !isDrawingMode && !isDrawControl && !hasExistingShapes) {
          self.moveOrPlaceMarker(e);
        }
      });
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

    // Add polygon drawing controls if editable
    console.log("this.editable", this.editable)
    console.log("MapboxDraw", MapboxDraw)

    if (this.editable && typeof MapboxDraw !== 'undefined') {
      this.initializePolygonEditor();
    }
  };

  MapboxMap.prototype.initializePolygonEditor = function() {
    var self = this;
    console.log("initializePolygonEditor")

    // Initialize Mapbox Draw
    this.draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: {
        polygon: true,
        point: true,
        line_string: true,
        trash: true
      },
      defaultMode: 'simple_select' // Start in selection mode, not drawing mode
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
      // Remove any existing markers when a shape is created
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
      console.log('Draw mode changed to:', e.mode);
      // If entering a drawing mode, clear any existing markers
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

  MapboxMap.prototype.createMarker = function(latitude, longitude, color, iconClass) {
    var styledMarker = this.getStyledMarker(color, iconClass);
    var markerOptions = {
      element: styledMarker.element,
      anchor: 'bottom',
      offset: [0, -10],
      draggable: this.editable
    };

    var marker = new mapboxgl.Marker(markerOptions)
      .setLngLat([longitude, latitude]);

    if (this.editable) {
      marker.on("dragend", this.updateFormfieldsWithMarker.bind(this));
    }
    marker.addTo(this.map);

    // Add marker to our markers array
    this.markers.push(marker);

    return marker;
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

    // Clear any existing polygons when placing a marker
    if (this.draw) {
      this.draw.deleteAll();
      // Switch draw mode to simple_select to avoid conflicts
      this.draw.changeMode('simple_select');
    }

    // Move existing marker
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
    if (this.markers.length) {
      this.markers.forEach(function(marker) {
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
      .setHTML('<div class="map-popup-status-message">Loading...</div>')
      .addTo(self.map);

    var popupDataUrl = self.getPopupDataUrl(resourceType, properties)

    if (!popupDataUrl) return;

    $.ajax(popupDataUrl, {
      type: "GET",
      dataType: "json"
    })
      .then(function(data) {
        popup.setHTML(App.MapPopup.getPopupContent(data), resourceType);
      })
      .fail(function() {
        popup.setHTML('<div class="map-popup-status-message error">Failed to load data</div>');
      })
  };



  MapboxMap.prototype.getPopupDataUrl = function(resourceType, properties) {
    if (resourceType == "proposal") {
      return "/proposals/" + properties.id + "/json_data";
    } else if (resourceType == "deficiency_report") {
      return "/deficiency_reports/" + properties.id + "/json_data";
    } else if (resourceType == "projekt") {
      return "/projekts/" + properties.id + "/json_data";
    } else if (resourceType == "investment") {
      return "/investments/" + properties.id + "/json_data";
    } else if (resourceType == "point_of_interest_pin") {
      return "/projekt_point_of_interest_pins/" + properties.id + "/json_data?projekt_phase_id=" + properties.projektPhaseId;
    }
  }

  MapboxMap.prototype.addMarkers = function() {
    var self = this;

    if (this.adminShape && this.showAdminShape) {
      this.addAdminShape();
    }

    if (this.processCoordinates) {
      // console.log("processCoordinates", this.processCoordinates);

      // Create a GeoJSON source for all markers
      var markers = {
        type: 'FeatureCollection',
        features: this.processCoordinates.filter(function(markerCoordinate) {
          var isValid = App.Mapbox.validCoordinates(markerCoordinate);
          return isValid;
        }).map(function(markerCoordinate) {
          var feature = {
            type: 'Feature',
            id: markerCoordinate.id, // Add feature ID for feature-state
            geometry: {
              type: 'Point',
              coordinates: [parseFloat(markerCoordinate.long), parseFloat(markerCoordinate.lat)]
            },
            properties: {
              id: markerCoordinate.id,
              resource_type: markerCoordinate.resource_type,
              color: markerCoordinate.color,
              iconClass: markerCoordinate.fa_icon_class,
              fa_icon_class: markerCoordinate.fa_icon_class // Ensure this matches the marker image name
            }
          };

          return feature;
        })
      };

      // Add the source to the map
      self.map.addSource('markers', {
        type: 'geojson',
        data: markers,
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50
      });

      // Get brand color from CSS variable with fallback
      var brandColor = getComputedStyle(document.documentElement).getPropertyValue('--brand-color').trim() || '#004a83';

      var clusterColor = hexToRgba(brandColor, 0.5);

      // console.log("brandColor", brandColor)
      // console.log("clusterColor", clusterColor)

      // Add cluster layer
      self.map.addLayer({
        id: 'clusters',
        type: 'circle',
        source: 'markers',
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
            15,
            10,
            20,
            30,
            25
          ]
        }
      });

      // Add cluster count layer
      self.map.addLayer({
        id: 'cluster-count',
        type: 'symbol',
        source: 'markers',
        filter: ['has', 'point_count'],
        layout: {
          'text-field': '{point_count_abbreviated}',
          'text-font': ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
          'text-size': 12
        }
      });

      // Add background circle layer
      self.map.addLayer({
        id: 'custom-marker',
        type: 'circle',
        source: 'markers',
        filter: ['!', ['has', 'point_count']],
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

      // Load all marker images
      if (this.markerImages && this.markerImages.length) {
        var loadedImages = 0;
        var totalImages = this.markerImages.length;

        this.markerImages.forEach(function(markerImage) {
          self.map.loadImage(markerImage.path, function(error, image) {
            if (error) {
              console.error('Error loading marker image:', error, markerImage);
              loadedImages++;
            } else {
              self.map.addImage(markerImage.name, image);
              loadedImages++;
            }

            // When all images are loaded, add the unclustered point layer
            if (loadedImages === totalImages) {
              self.setupIconLayer()
            }
          });
        });
      } else {
        self.setupIconLayer()
      }

      // Add click handler for clusters
      self.map.on('click', 'clusters', function(e) {
        var features = self.map.queryRenderedFeatures(e.point, {
          layers: ['clusters']
        });
        var clusterId = features[0].properties.cluster_id;
        self.map.getSource('markers').getClusterExpansionZoom(
          clusterId,
          function(err, zoom) {
            if (err) return;

            self.map.easeTo({
              center: features[0].geometry.coordinates,
              zoom: zoom
            });
          }
        );
      });

      // Change cursor on hover
      self.map.on('mouseenter', 'clusters', function() {
        self.map.getCanvas().style.cursor = 'pointer';
      });
      self.map.on('mouseleave', 'clusters', function() {
        self.map.getCanvas().style.cursor = '';
      });

      if (!this.editable) {
        console.log("try to drawCoordinateCustomShape", this.processCoordinates)
        // Add shapes for non-marker coordinates
        this.processCoordinates.forEach(function(coordinates) {
          if (!App.Mapbox.validCoordinates(coordinates)) {
            console.log("drawCoordinateCustomShape", coordinates)
            self.drawCoordinateCustomShape(coordinates);
          }
        });
      }
    }
  };

  MapboxMap.prototype.setupIconLayer = function(e) {
    var self = this;

    // Remove existing layer if it exists
    if (self.map.getLayer('custom-marker-icon')) {
      self.map.removeLayer('custom-marker-icon');
    }

    // Add the unclustered point layer
    self.map.addLayer({
      id: 'custom-marker-icon',
      type: 'symbol',
      source: 'markers',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': ['get', 'fa_icon_class'],
        'icon-size': 0.35,
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        'icon-anchor': 'center',
      }
    }, null);

    self.setupMarkerEventListeners(e);
  }

  MapboxMap.prototype.setupMarkerEventListeners = function() {
    var self = this;

    self.map.on('mouseenter', 'custom-marker',
      self.handleMarkerMouseEnter.bind(self)
    );
    self.map.on('mouseleave', 'custom-marker',
      self.handleMarkerMouseLeave.bind(self)
    );

    // Show popup on click
    self.map.on('click', 'custom-marker',
      self.openMarkerPopup.bind(self)
    );
  };

  MapboxMap.prototype.handleMarkerMouseEnter = function(e) {
    this.map.getCanvas().style.cursor = 'pointer';

    if (e.features.length > 0) {
      if (this.hoveredFeature !== null) {
        this.map.setFeatureState(
          { source: 'markers', id: this.hoveredFeature },
          { hover: false }
        );
      }
      this.hoveredFeature = e.features[0].id;
      this.map.setFeatureState(
        { source: 'markers', id: this.hoveredFeature },
        { hover: true }
      );
    }
  };

  MapboxMap.prototype.handleMarkerMouseLeave = function() {
    this.map.getCanvas().style.cursor = '';

    if (this.hoveredFeature !== null) {
      this.map.setFeatureState(
        { source: 'markers', id: this.hoveredFeature },
        { hover: false }
      );
    }
    this.hoveredFeature = null;
  };

  MapboxMap.prototype.addAdminShape = function() {
    if (App.Mapbox.validCoordinates(this.adminShape)) {
      if (this.adminEditor) {
        this.createMarker(
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
      this.addShapeLayer('admin-shape', this.adminShape, this.adminShapesColor);
    }
  };

  MapboxMap.prototype.drawCoordinateCustomShape = function(coordinates) {
    var self = this;
    // Generate a unique ID if coordinates.id is undefined
    var shapeId = coordinates.id || 'shape-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    var sourceId = 'user-shape-' + shapeId;
    var layerId = 'user-shape-layer-' + shapeId;

    // Check if source already exists to prevent duplicate source error
    if (this.map.getSource(sourceId)) {
      console.warn('Source with ID', sourceId, 'already exists. Skipping...');
      return;
    }

    this.map.addSource(sourceId, {
      type: 'geojson',
      data: coordinates
    });

    this.map.addLayer({
      id: layerId,
      type: 'fill',
      source: sourceId,
      paint: {
        'fill-color': coordinates.color,
        'fill-opacity': 0.55
      }
    });

    this.map.on('click', layerId, function(e) {
      // console.log("map on click")
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
    });
  };

  MapboxMap.prototype.addShapeLayer = function(id, data, color) {
    var self = this;

    this.map.addSource(id, {
      type: 'geojson',
      data: data
    });

    this.map.addLayer({
      id: id + '-layer',
      type: 'fill',
      source: id,
      paint: {
        'fill-color': color,
        'fill-opacity': 0.4
      }
    });

    if (!this.editable) {
      this.map.on('click', id + '-layer', function() {
        new mapboxgl.Popup()
          .setLngLat(self.map.getCenter())
          .setHTML('Alle markierten Flächen und Pins in rot sind vom System vorgegeben')
          .addTo(self.map);
      });
    }
  };

    // Add a method to clean up markers
  MapboxMap.prototype.destroy = function() {
    // Clean up draw instance
    if (this.draw) {
      this.map.removeControl(this.draw);
      this.draw = null;
    }

    this.markers.forEach(function(marker) {
      marker.remove();
    });
    this.markers = [];
    if (this.adminMarker) {
      this.adminMarker.remove();
      this.adminMarker = null;
    }
    if (this.editableMarker) {
      this.editableMarker.remove();
      this.editableMarker = null;
    }
  };

  // Keep the existing App.Mapbox object
  App.Mapbox = {
    maps: [],
    initialize: function() {
      var self = this;
      $("[data-mapbox]").each(function() {
        var element = this;
        var mapInstance = self.initializeFor(element)

        self.maps.push(mapInstance.map)
      });
    },
    initializeFor: function(element) {
      return new MapboxMap(element);
    },
    destroy: function() {
      this.maps.forEach(function(map) {
        map.remove();
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

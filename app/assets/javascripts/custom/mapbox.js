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
    this.processCoordinates = $element.data("process-coordinates");
    this.editable = $element.data("editable");
    this.adminEditor = $element.data("admin-editor");
    this.adminShape = $element.data("admin-shape");
    this.showAdminShape = $element.data("show-admin-shape");
    this.latitudeInputSelector = $element.data("latitude-input-selector");
    this.longitudeInputSelector = $element.data("longitude-input-selector");
    this.zoomInputSelector = $element.data("zoom-input-selector");
    this.shapeInputSelector = $element.data("shape-input-selector");
    this.showAdminShapeInputSelector = $element.data("show-admin-shape-input-selector");
    this.$categorySelect = $(".js-map-update-pin-style");
    this.markerImages = $element.data("mapbox-marker-images")

    this.map = null;
    this.markers = []; // Array to store all markers
    this.adminMarker = null;
    this.markerCategoryIcon = null;
    this.markerCategoryColor = null;
    this.adminShapesColor = 'red';
    this.defaultMarkerBackgroundCircleRadius = 14;
    this.hoveredFeature = null;

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
        $(self.zoomInputSelector).val(self.map.getZoom());
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
  };

  MapboxMap.prototype.getMarkerIcon = function(color, iconClass) {
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
      anchor: [15, 40]
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
    var markerOptions = {
      element: this.getMarkerIcon(color, iconClass).element,
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
    $(this.zoomInputSelector).val(this.map.getZoom());
    $(this.shapeInputSelector).val(JSON.stringify({}));

    if (this.adminEditor) {
      $(this.showAdminShapeInputSelector).val(true);
    }
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
        marker.setIcon(this.getMarkerIcon(null, null));
      }.bind(this));
    }
  };

  MapboxMap.prototype.openMarkerPopup = function(e) {
    var self = this;

    console.log("handle click on marker")
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
      console.log("processCoordinates", this.processCoordinates);

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

      console.log('Created markers GeoJSON:', markers);

      // Add the source to the map
      self.map.addSource('markers', {
        type: 'geojson',
        data: markers,
        cluster: true,
        clusterMaxZoom: 14,
        clusterRadius: 50
      });

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
            'rgba(25.5, 77.7, 127.2, 0.5)',   // small clusters (e.g. < 10)
            10, 'rgba(25.5, 77.7, 127.2, 0.5)', // medium clusters (e.g. < 30)
            30, 'rgba(25.5, 77.7, 127.2, 0.5)'  // large clusters (30+)
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
        console.log('Starting to load marker images:', this.markerImages);

        console.log("markerImages", this.markerImages)
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

      // Add shapes for non-marker coordinates
      this.processCoordinates.forEach(function(coordinates) {
        if (!App.Mapbox.validCoordinates(coordinates)) {
          self.addProcessShape(coordinates);
        }
      });
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
        this.adminMarker = new mapboxgl.Marker({
          element: this.getMarkerIcon(this.adminShapesColor, this.adminShape.fa_icon_class).element
        })
          .setLngLat([this.adminShape.long, this.adminShape.lat])
          .setPopup(new mapboxgl.Popup().setHTML('Alle markierten Flächen und Pins in rot sind vom System vorgegeben'))
          .addTo(this.map);
      }
    } else if (Object.keys(this.adminShape).length > 0) {
      this.addShapeLayer('admin-shape', this.adminShape, this.adminShapesColor);
    }
  };

  MapboxMap.prototype.addProcessShape = function(coordinates) {
    var self = this;
    var sourceId = 'user-shape-' + coordinates.id;
    var layerId = 'user-shape-layer-' + coordinates.id;

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
        'fill-opacity': 0.4
      }
    });

    this.map.on('click', layerId, function() {
      console.log("map on click")
      self.openMarkerPopup({ target: { options: { id: coordinates.id } } });
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
    this.markers.forEach(function(marker) {
      marker.remove();
    });
    this.markers = [];
    if (this.adminMarker) {
      this.adminMarker.remove();
      this.adminMarker = null;
    }
  };

  // Keep the existing App.Mapbox object
  App.Mapbox = {
    maps: [],
    initialize: function() {
      $("[data-mapbox]").each(function() {
        var element = this;
        new MapboxMap(element);
      });
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

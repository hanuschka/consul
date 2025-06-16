(function() {
  "use strict";

  // MapboxMap class definition
  function MapboxMap(element) {
    this.element = element;
    var $element = $(element);

    this.mapCenterLatitude = $element.data("map-center-latitude");
    this.mapCenterLongitude = $element.data("map-center-longitude");
    this.zoom = $element.data("map-zoom");
    this.process = $element.data("parent-class");
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
      style: 'mapbox://styles/mapbox/streets-v11',
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
    var route;
    var markerElement = e.target || e.currentTarget;
    var id = markerElement.dataset.id;
    var projektPhaseId = markerElement.dataset.projektPhaseId;

    if (this.process == "proposals") {
      route = "/proposals/" + id + "/json_data";
    } else if (this.process == "deficiency-reports") {
      route = "/deficiency_reports/" + id + "/json_data";
    } else if (this.process == "projekts") {
      route = "/projekts/" + id + "/json_data";
    } else if (this.process == "budgets") {
      route = "/investments/" + id + "/json_data";
    } else if (this.process == "point-of-interest-pin") {
      route = "/projekt_point_of_interest_pins/" + id + "/json_data?projekt_phase_id=" + projektPhaseId;
    }

    if (!route) { return; }

    $.ajax(route, {
      type: "GET",
      dataType: "json",
      success: function(data) {
        var popup = new mapboxgl.Popup({
          offset: [0, -20],
          closeButton: false,
          maxWidth: '200px'
        })
          .setLngLat(markerElement.getLngLat())
          .setHTML(App.MapPopup.getPopupContent(data))
          .addTo(self.map);
      }
    });
  };

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
        features: this.processCoordinates.filter(function(coords) {
          var isValid = App.Mapbox.validCoordinates(coords);
          console.log("coordinates validation:", coords, isValid);
          return isValid;
        }).map(function(coords) {
          var feature = {
            type: 'Feature',
            geometry: {
              type: 'Point',
              coordinates: [parseFloat(coords.long), parseFloat(coords.lat)]
            },
            properties: {
              color: coords.color,
              iconClass: coords.fa_icon_class,
              fa_icon_class: coords.fa_icon_class // Ensure this matches the marker image name
            }
          };

          // Add the appropriate ID based on process type
          if (self.process == "proposals") {
            feature.properties.id = coords.proposal_id;
          } else if (self.process == "deficiency-reports") {
            feature.properties.id = coords.deficiency_report_id;
          } else if (self.process == "projekts") {
            feature.properties.id = coords.projekt_id;
          } else if (self.process == "point-of-interest-pin") {
            feature.properties.id = coords.point_of_interest_pin_id;
            feature.properties.projektPhaseId = coords.projekt_phase_id;
          } else {
            feature.properties.id = coords.investment_id;
          }

          console.log('Created feature:', feature);
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
            '#51bbd6',
            100, '#f1f075',
            750, '#f28cb1'
          ],
          'circle-radius': [
            'step',
            ['get', 'point_count'],
            20,
            100, 30,
            750, 40
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
        id: 'unclustered-point-background',
        type: 'circle',
        source: 'markers',
        filter: ['!', ['has', 'point_count']],
        paint: {
          'circle-color': ['coalesce', ['get', 'color'], '#ff0000'],
          'circle-radius': self.defaultMarkerBackgroundCircleRadius,
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
              self.setupMarkerEventListeners()
            }
          });
        });
      } else {
        self.setupMarkerEventListeners()
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

  MapboxMap.prototype.setupMarkerEventListeners = function() {
    console.log('All images loaded, adding icon layer');
    var self = this;

    // Remove existing layer if it exists
    if (self.map.getLayer('unclustered-point')) {
      self.map.removeLayer('unclustered-point');
    }

    // Add the unclustered point layer
    self.map.addLayer({
      id: 'unclustered-point',
      type: 'symbol',
      source: 'markers',
      filter: ['!', ['has', 'point_count']],
      layout: {
        'icon-image': ['get', 'fa_icon_class'],
        'icon-size': 0.35,
        'icon-allow-overlap': true,
        'icon-ignore-placement': true,
        // 'icon-anchor': 'center',
      }
    }, null);

    // Add hover effect
    self.map.on('mouseenter', 'unclustered-point', function() {
      self.map.getCanvas().style.cursor = 'pointer';
      self.map.setPaintProperty('unclustered-point-background', 'circle-radius', self.defaultMarkerBackgroundCircleRadius + 1);
    });

    self.map.on('mouseleave', 'unclustered-point', function() {
      self.map.getCanvas().style.cursor = '';
      self.map.setPaintProperty('unclustered-point-background', 'circle-radius', self.defaultMarkerBackgroundCircleRadius);
    });

    // Add click handler for individual markers
    console.log("add a click on marker")
    self.map.on('click', 'unclustered-point', function(e) {
      var coordinates = e.features[0].geometry.coordinates.slice();
      var properties = e.features[0].properties;

      // Show empty popup immediately
      var popup = new mapboxgl.Popup({
        offset: [0, -20],
        closeButton: true,
        maxWidth: '200px'
      })
        .setLngLat(coordinates)
        .setHTML('<div class="map-popup-loading">Loading...</div>')
        .addTo(self.map);

      var route;
      if (self.process == "proposals") {
        route = "/proposals/" + properties.id + "/json_data";
      } else if (self.process == "deficiency-reports") {
        route = "/deficiency_reports/" + properties.id + "/json_data";
      } else if (self.process == "projekts") {
        route = "/projekts/" + properties.id + "/json_data";
      } else if (self.process == "budgets") {
        route = "/investments/" + properties.id + "/json_data";
      } else if (self.process == "point-of-interest-pin") {
        route = "/projekt_point_of_interest_pins/" + properties.id + "/json_data?projekt_phase_id=" + properties.projektPhaseId;
      }

      if (!route) { return; }

      $.ajax(route, {
        type: "GET",
        dataType: "json",
        success: function(data) {
          popup.setHTML(App.MapPopup.getPopupContent(data), self.process);
        },
        error: function() {
          popup.setHTML('<div class="error">Failed to load data</div>');
        }
      });
    });

    // Verify layer was added
    console.log('Layer added:', self.map.getLayer('unclustered-point'));
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

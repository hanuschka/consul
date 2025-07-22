(function() {
  "use strict";
  // Custom Leaflet control for fullscreen modal functionality
  L.Control.FullscreenModal = L.Control.extend({
    options: {
      position: 'topright'
    },

    initialize: function(options) {
      L.Control.prototype.initialize.call(this, options);
      this.originalElement = options.element;
      this.modalId = 'leaflet-fullscreen-modal-' + Date.now();
      this.modalMapElement = null;
      this.isInModal = false;
    },

    onAdd: function(map) {
      this._map = map;
      
      // Create control container
      var container = L.DomUtil.create('div', 'leaflet-control-fullscreen leaflet-bar leaflet-control');
      
      // Create button
      var button = L.DomUtil.create('a', 'leaflet-control-fullscreen-button', container);
      button.href = '#';
      button.title = 'Vollbild-Modus';
      button.innerHTML = '<i class="fas fa-expand"></i>';
      
      // Prevent map events when clicking button
      L.DomEvent.disableClickPropagation(button);
      L.DomEvent.disableScrollPropagation(button);
      
      // Add click handler
      L.DomEvent.on(button, 'click', this.openModal, this);
      
      return container;
    },

    openModal: function(e) {
      L.DomEvent.preventDefault(e);
      
      if (this.isInModal) return;
      
      this.createModalStructure();
      this.initializeModalMap();
      this.showFoundationModal();
      
      this.isInModal = true;
    },

    createModalStructure: function() {
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
      var self = this;

      // Set up event listeners
      $(modal).on('closed.zf.reveal', function() {
        self.closeModal();
      });

      var closeButton = modal.querySelector('.map-modal--close-button');
      if (closeButton) {
        closeButton.addEventListener('click', function() {
          self.closeModal();
        });
      }

      // ESC key handler
      this.escHandler = function(e) {
        if (e.key === 'Escape' && self.isInModal) {
          self.closeModal();
          document.removeEventListener('keydown', self.escHandler);
        }
      };
      document.addEventListener('keydown', this.escHandler);
    },

    initializeModalMap: function() {
      var modalContainer = document.getElementById(this.modalId + '-map-container');
      
      // Copy all data attributes from original element
      this.copyDataAttributes(this.originalElement, modalContainer);
      
      // Mark as modal map
      modalContainer.setAttribute('data-modal-map', 'true');
      
      // Get current map state
      var center = this._map.getCenter();
      var zoom = this._map.getZoom();
      
      // Override center and zoom with current values
      modalContainer.setAttribute('data-map-center-latitude', center.lat);
      modalContainer.setAttribute('data-map-center-longitude', center.lng);
      modalContainer.setAttribute('data-map-zoom', zoom);
      
      // Set unique ID for modal map
      modalContainer.id = this.modalId + '-map';
      
      // Store reference for cleanup
      this.modalMapElement = modalContainer;
      
      // Initialize new Leaflet map in modal after a short delay
      setTimeout(() => {
        App.Map.initializeMap(modalContainer);
        
        // Find the newly created map and sync view
        var modalMap = App.Map.maps[App.Map.maps.length - 1];
        if (modalMap) {
          modalMap.setView(center, zoom);
        }
      }, 100);
    },

    copyDataAttributes: function(sourceElement, targetElement) {
      // Copy all data attributes using jQuery
      var data = $(sourceElement).data();
      
      for (var key in data) {
        if (data.hasOwnProperty(key)) {
          $(targetElement).data(key, data[key]);
          targetElement.setAttribute('data-' + this.camelToKebab(key), data[key]);
        }
      }
    },

    camelToKebab: function(str) {
      return str.replace(/([a-z0-9]|(?=[A-Z]))([A-Z])/g, '$1-$2').toLowerCase();
    },

    showFoundationModal: function() {
      var modal = new Foundation.Reveal($('#' + this.modalId));
      modal.open();
    },

    closeModal: function() {
      if (!this.isInModal) return;
      
      console.log('Closing Leaflet modal and destroying map...');
      
      try {
        this.isInModal = false;
        
        // Find and destroy the modal map
        if (this.modalMapElement) {
          var modalMapId = this.modalMapElement.id;
          
          // Find the map instance in App.Map.maps array
          var mapIndex = -1;
          App.Map.maps.forEach((map, index) => {
            var container = map.getContainer();
            if (container && container.id === modalMapId) {
              mapIndex = index;
            }
          });
          
          // Remove and destroy the map
          if (mapIndex >= 0) {
            var modalMap = App.Map.maps[mapIndex];
            modalMap.off();
            modalMap.remove();
            App.Map.maps.splice(mapIndex, 1);
            console.log('Modal map destroyed');
          }
          
          this.modalMapElement = null;
        }
        
        // Clean up escape handler
        if (this.escHandler) {
          document.removeEventListener('keydown', this.escHandler);
          this.escHandler = null;
        }
        
        // Remove modal HTML
        setTimeout(() => {
          var modalElement = document.getElementById(this.modalId);
          if (modalElement) {
            modalElement.remove();
            console.log('Modal HTML removed');
          }
        }, 50);
        
      } catch (e) {
        console.error('Error closing Leaflet modal:', e);
        this.isInModal = false;
      }
    }
  });

  App.Map = {
    maps: [],
    initialize: function() {
      $("*[data-map]:visible").each(function() {
        App.Map.initializeMap(this);
      });

      App.Mapbox.initialize();
    },
    destroy: function() {
      App.Map.maps.forEach(function(map) {
        map.off();
        map.remove();
      });
      App.Map.maps = [];

      App.Mapbox.destroy();
    },
    initializeMap: function(element) {
      // variables to set map view
      var mapCenterLatitude = $(element).data("map-center-latitude");
      var mapCenterLongitude = $(element).data("map-center-longitude");
      var mapCenterLatLng = new L.LatLng(mapCenterLatitude, mapCenterLongitude);
      var zoom = $(element).data("map-zoom");

      // tile and overlay layers for map
      var layersData = $(element).data('map-layers');
      var baseLayers = {};
      var overlayLayers = {};
      var adminMarker = null;
      var adminShape = $(element).data("admin-shape");
      var showAdminShape = $(element).data("show-admin-shape");

      // variables that define map editing behaviour
      var adminEditor = $(element).data("admin-editor");
      var adminShapesColor = 'red';

      // variables that define location and tooltips of process coordinates (both pins and shapes)
      var process = $(element).data("parent-class");
      var processCoordinates = $(element).data("process-coordinates");

      // variables to define map form input selectors
      var latitudeInputSelector = $(element).data("latitude-input-selector");
      var longitudeInputSelector = $(element).data("longitude-input-selector");
      var zoomInputSelector = $(element).data("zoom-input-selector");
      var shapeInputSelector = $(element).data("shape-input-selector");
      var showAdminShapeInputSelector = $(element).data("show-admin-shape-input-selector");

      // defines if it's allowed to edit map
      var editable = $(element).data("editable");
      var enableGeomanControls = $(element).data("enable-geoman-controls");

      // biolerplate for marker
      var marker = null;
      var markersGroup = L.markerClusterGroup({ removeOutsideVisibleBounds: false });

      var userMarkerCategoryIcon = null;
      var userMarkerCategoryColor = null;
      var $categorySelect = $(".js-map-update-pin-style");

      $categorySelect.on(
        "change",
        function(e) { updateMarkerStyleFromCategorySelect(e.target) }
      )

      if ($categorySelect.length) {
        updateMarkerStyleFromCategorySelect($categorySelect.get(0))
      }

      /* Create leaflet map start */
      var map = L.map(element.id, {
        gestureHandling: true,
        maxZoom: 18,
        zoomControl: false
      }).setView(mapCenterLatLng, zoom);
      App.Map.maps.push(map);

      var zoomControl = L.control.zoom({
        zoomInTitle: 'Hineinzoomen',
        zoomOutTitle: 'Herauszoomen'
      });
      map.addControl(zoomControl);

      // Add fullscreen modal control if not already in modal
      if (!$(element).data('modal-map')) {
        var fullscreenControl = new L.Control.FullscreenModal({ element: element });
        map.addControl(fullscreenControl);
      }

      // update form fields when map center changes
      map.on("moveend", function() {
        if ( adminEditor) {
          $(latitudeInputSelector).val(map.getCenter().lat);
          $(longitudeInputSelector).val(map.getCenter().lng);
          $(zoomInputSelector).val(map.getZoom());
        }
      });
      /* Create leaflet map end */


      /* Leaflet basic plugins start */
      // Leaflet.Locate plugin: ads control to map
      L.control.locate({
        icon: 'fa fa-map-marker',
        strings: {
          title: 'Meine Position anzeigen'
        }
      }).addTo(map);

      // Leaflet GeoSearch plugin: adds control to map
      var searchControl = new GeoSearch.GeoSearchControl({
        provider: new GeoSearch.OpenStreetMapProvider(),
        style: 'bar',
        showMarker: false,
        searchLabel: 'Nach Adresse suchen',
        notFoundMessage: 'Entschuldigung! Die Adresse wurde nicht gefunden.',
        clearSearchLabel: 'Suche zurücksetzen'
      });
      map.addControl(searchControl);

      // Leaflet.Deflate plugin: replaces shapes with markers when they are too small
      const deflateFeatures = L.deflate({
        minSize: 10,
        markerLayer: markersGroup,
        markerOptions: function(shape) {
          return {
            icon: getMarkerIcon(shape.feature.color, shape.feature.fa_icon_class),
            id: getProcessId(shape)
          }
        }
      })
      deflateFeatures.addTo(map);

      function updateMarkerWithCategoryStyle() {
        if (marker && userMarkerCategoryIcon && userMarkerCategoryColor) {
          marker.setIcon(getMarkerIcon(userMarkerCategoryColor, userMarkerCategoryIcon))
        }
      }

      function updateMarkerStyleFromCategorySelect(element) {
        var selectedOption = element.options[element.selectedIndex]

        userMarkerCategoryIcon = selectedOption.dataset.icon;
        userMarkerCategoryColor = selectedOption.dataset.color;

        updateMarkerWithCategoryStyle()
      }

      function getProcessId(shape) {
        var id;

        if (process == "proposals") {
          id = shape.feature.proposal_id
        } else if (process == "deficiency-reports") {
          id = shape.feature.deficiency_report_id
        } else if (process == "projekts") {
          id = shape.feature.projekt_id
        } else if (process == "budgets"){
          id = shape.feature.investment_id
        }

        return id
      }
      /* Leaflet basic plugins end */


      /* Function definitions start */
      // function to create a marker

      function getMarkerIcon(color, iconClass) {
        return L.divIcon({
          className: "map-marker",
          iconSize: [30, 30],
          iconAnchor: [15, 40],
          html: getMarkerIconHTML(color, iconClass)
        })
      }

      function getMarkerIconHTML(color, iconClass) {
        var markerIconHTML;

        if (iconClass && iconClass.length > 0) {
          iconClass = iconClass
        } else {
          iconClass = 'circle';
        };

        if (adminEditor) {
          color = adminShapesColor;
        }

        if (color) {
          markerIconHTML = '<div class="map-icon icon-' + iconClass + '" style="background-color: ' + color + '"></div>'
        } else {
          markerIconHTML = '<div class="map-icon icon-' + iconClass + '"></div>'
        }

        return markerIconHTML;
      }

      var createMarker = function(latitude, longitude, color, iconClass) {
        var markerLatLng = new L.LatLng(latitude, longitude);

        if (userMarkerCategoryIcon) {
          iconClass = userMarkerCategoryIcon;
        }

        if (userMarkerCategoryColor) {
          color = userMarkerCategoryColor;
        }

        marker = L.marker(markerLatLng, {
          icon: getMarkerIcon(color, iconClass),
          draggable: editable
        });

        if (editable) {
          marker.on("dragend", updateFormfieldsWithMarker);
          marker.addTo(map);
        } else {
          markersGroup.addLayer(marker);
        }

        return marker;
      };

      // function to create or move existing marker
      var moveOrPlaceMarker = function(e) {
        if (adminEditor) {
          // In admin mode, always create new markers
          marker = createMarker(e.latlng.lat, e.latlng.lng);
        } else {
          // In user mode, move existing or create new
          if (marker) {
            marker.setLatLng(e.latlng);
            updateMarkerWithCategoryStyle()
          } else {
            marker = createMarker(e.latlng.lat, e.latlng.lng);
          }
        }
        updateFormfieldsWithMarker();
      };

      // Do not delete. This is interface function used to update
      // map in other js componentns and in AI assistants
      this.lastMapSetMarkerTo = function lastMapSetMarkerTo(lat, lng) {
        if (App.Map.maps.length > 1) {
          // Due to limitation of implementation of this functions
          // it dosent work when there multiple instances of map
          return
        }
        if (marker) {
          marker.setLatLng([lat, lng]);
        } else {
          marker = createMarker(lat, lng);
        }
        updateFormfieldsWithMarker();
      }

      // function to update form fields when marker is updated
      var updateFormfieldsWithMarker = function() {
        $(zoomInputSelector).val(map.getZoom());

        if (adminEditor) {
          // For admin editor, collect all markers and shapes
          var allFeatures = [];

          // Collect all drawn shapes
          map.pm.getGeomanLayers().forEach(function(geomanLayer) {
            if (geomanLayer.pm.options.adminShape != true) {
              var layerCopy = geomanLayer;
              if (geomanLayer.options.shape == 'Circle') {
                layerCopy = L.PM.Utils.circleToPolygon(geomanLayer, 60);
              }
              var feature = layerCopy.toGeoJSON();
              feature.properties = feature.properties || {};
              feature.properties.color = adminShapesColor;
              feature.properties.fa_icon_class = 'circle';
              allFeatures.push(feature);
            }
          });

          // Collect all markers that are not in the cluster group
          map.eachLayer(function(layer) {
            if (layer instanceof L.Marker &&
                layer !== adminMarker &&
                !layer.pm.options.adminShape &&
                !markersGroup.hasLayer(layer)) {
              var feature = {
                type: 'Feature',
                geometry: {
                  type: 'Point',
                  coordinates: [layer.getLatLng().lng, layer.getLatLng().lat]
                },
                properties: {
                  color: adminShapesColor,
                  fa_icon_class: 'circle'
                }
              };
              allFeatures.push(feature);
            }
          });

          if (allFeatures.length > 0) {
            // Create FeatureCollection for multiple features
            var featureCollection = {
              type: 'FeatureCollection',
              features: allFeatures
            };
            $(shapeInputSelector).val(JSON.stringify(featureCollection));
            // Clear single coordinate fields when using multiple items
            $(latitudeInputSelector).val('');
            $(longitudeInputSelector).val('');
          } else if (marker) {
            // Single marker case
            $(latitudeInputSelector).val(marker.getLatLng().lat);
            $(longitudeInputSelector).val(marker.getLatLng().lng);

            $(shapeInputSelector).val(JSON.stringify({}));
          }

          $(showAdminShapeInputSelector).val(true);
        } else {
          // For regular users, single marker only
          $(latitudeInputSelector).val(marker.getLatLng().lat);
          $(longitudeInputSelector).val(marker.getLatLng().lng);
          $(shapeInputSelector).val(JSON.stringify({}));
        }
      };

      // function to open marker popup
      var openMarkerPopup = function(e) {
        var resourceType = e.target.options.resource_type;
        var route = App.MapPopup.getPopupDataUrl(resourceType, e.target.options)

        if (!route) return;

        marker = e.target;
        $.ajax(route, {
          type: "GET",
          dataType: "json",
          success: function(data) {
            e.target.bindPopup(App.MapPopup.generatePopupContent(data, resourceType), { autoPanPadding: [0, 80], minWidth: 200, offset:  L.point(0, -30) }).openPopup();
          }
        });
      };

      // functions to generate markup for popup content
      // function to add event listeners to the shape layer, used when shape layer is editable
      function addEventListenersToShapeLayer(layer) {
        layer.on('pm:edit', function(e) {
          updateShapeFieldInForm(e.layer);
        })

        layer.on('pm:dragend', function(e) {
          updateShapeFieldInForm(e.layer);
        })

        // allows multiple cuts
        layer.on('pm:cut', function(e) {
          if (typeof(e.layer.getLatLngs) == 'function') {
            e.originalLayer.setLatLngs(e.layer.getLatLngs());
            e.originalLayer.addTo(map);
            e.originalLayer._pmTempLayer = false;

            e.layer._pmTempLayer = true;
            e.layer.remove();

            // Update form fields after cut operation in admin mode
            if (adminEditor) {
              setTimeout(function() {
                updateShapeFieldInForm(null);
              }, 10);
            }
          }
        })
      }
      /* Function definitions end */


      /* Assembles a map: start */
      // function to create tile or overlay layer
      var createLayer = function(item, index) {

        if ( item.protocol == 'wms' ) {
          var layer = L.tileLayer.wms(item.provider, {
            attribution: item.attribution,
            layers: item.layer_names,
            format: (item.transparent ? 'image/png' : 'image/jpeg'),
            transparent: (item.transparent),
            show_by_default: (item.show_by_default),
            opacity: (item.opacity ? item.opacity : 1),
          });

        } else {
          var layer = L.tileLayer(item.provider, {
            attribution: item.attribution
          });

        }

        if ( item.base ) {
          baseLayers[item.name] = layer;
        } else {
          overlayLayers[item.name] = layer;
        }
      }

      // function to ensure that at least one base layer exists
      var ensureBaseLayerExistence = function() {
        if ( Object.keys(baseLayers).length === 0 ) {
          var defaultLayer = L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href=\"http://osm.org/copyright\">OpenStreetMap</a> contributors'
          });

          baseLayers['defaultLayer'] = defaultLayer;
        }
      }

      // creates tile and overlay layers if data is available
      if ( typeof layersData !== "undefined"  ) {
        layersData.forEach(createLayer);
      }

      // ensures that at least one base layer exists and adds it to map
      ensureBaseLayerExistence();
      baseLayers[Object.keys(baseLayers)[0]].addTo(map);

      // adds overlay layers to map if they should be visible by default
      if ( Object.keys(overlayLayers).length > 0 ) {
        for (let i = 0; i < Object.keys(overlayLayers).length; i++ ) {
          if ( overlayLayers[Object.keys(overlayLayers)[i]].options.show_by_default == true ) {
            overlayLayers[Object.keys(overlayLayers)[i]].addTo(map)
          }
        }
      }

      // adds layer control to map if there are more than one base and/or overlay layers
      if ( Object.keys(baseLayers).length > 1 && Object.keys(overlayLayers).length > 0 ) {
        L.control.layers(baseLayers, overlayLayers).addTo(map);
      } else if ( Object.keys(overlayLayers).length > 0 ) {
        L.control.layers({}, overlayLayers).addTo(map);
      }

      // render markers or shapes created by admin, if available
      if (adminShape && showAdminShape) {
        // Handle both single admin shape and array of admin shapes
        var adminShapes = Array.isArray(adminShape) ? adminShape : [adminShape];

        adminShapes.forEach(function(singleAdminShape) {
          if (App.Map.validCoordinates(singleAdminShape)) {
            if ( adminEditor ) {
              marker = createMarker(singleAdminShape.lat, singleAdminShape.long, adminShapesColor, singleAdminShape.fa_icon_class || 'circle');
            } else {
              var markerLatLng = new L.LatLng(singleAdminShape.lat, singleAdminShape.long);
              var adminMarker = L.marker(markerLatLng, {
                icon: getMarkerIcon(adminShapesColor, singleAdminShape.fa_icon_class || 'circle')
              });
              adminMarker.pm.setOptions({ adminShape: true })

              adminMarker.on("click", function() {
                if (!this._popup) {
                  this.bindPopup('Alle markierten Flächen und Pins in rot sind vom System vorgegeben').openPopup();
                }
              });

              adminMarker.addTo(map);
            }
          } else if (Object.keys(singleAdminShape).length > 0) {
            // Handle FeatureCollection with multiple features
            var features = singleAdminShape.features || [singleAdminShape];

            features.forEach(function(feature) {
              if (Object.keys(feature).length) {
                var adminShapeLayer = L.geoJSON(feature, {
                  pointToLayer: function(geoFeature, latlng) {
                    return L.marker(latlng, {
                      icon: getMarkerIcon(
                      geoFeature.properties.color || adminShapesColor,
                      geoFeature.properties.fa_icon_class || 'circle'
                    )
                    });
                  }
                });
              }

              adminShapeLayer.pm.setOptions({ adminShape: true })
              adminShapeLayer.setStyle({
                color: feature.properties.color || adminShapesColor,
                fillColor: feature.properties.color || adminShapesColor,
                fillOpacity: 0.2,
              })

              if (adminEditor) {
                addEventListenersToShapeLayer(adminShapeLayer)
              } else {
                adminShapeLayer.on("click", function() {
                  if (!this._popup) {
                    this.bindPopup('Alle markierten Flächen und Pins in rot sind vom System vorgegeben').openPopup();
                  }
                });
              }

              adminShapeLayer.addTo(map);
            });
          }
        });
      }

      // adds second attribution to tell about admin pins and shapes
      if ( showAdminShape ) {
        var adminShapeExplainerText = 'Alle markierten Flächen und Pins in rot sind vom System vorgegeben';
        var adminShapeExplainer = L.control({
          position: 'bottomleft'
        });
        adminShapeExplainer.onAdd = function(map) {
          var container = L.DomUtil.create('div', 'my-attribution');
          container.innerHTML = adminShapeExplainerText;
          container.className += ' leaflet-control-attribution';
          container.style.color = adminShapesColor;
          return container;
        }
        adminShapeExplainer.addTo(map);
      }


      // ads pins and shapes created by user
      if (processCoordinates) {
        processCoordinates.forEach(function(markerCoordinate) {
          if (App.Map.validCoordinates(markerCoordinate)) {
            marker = createMarker(markerCoordinate.lat, markerCoordinate.long, markerCoordinate.color, markerCoordinate.fa_icon_class);

            marker.options.id = markerCoordinate.id
            marker.options.resource_type = markerCoordinate.resource_type
            marker.options.projekt_phase_id = markerCoordinate.projekt_phase_id

            if ( App.MapPopup.excludedProcesses.indexOf(process) == -1 ) {
              marker.on("click", openMarkerPopup);
            }
          } else if (markerCoordinate.features && Array.isArray(markerCoordinate.features)) {
            // Handle GeoJSON FeatureCollection
            markerCoordinate.features.forEach(function(feature) {
              if (feature.geometry.type === 'Point') {
                // Render Point features as regular markers
                var coords = feature.geometry.coordinates;
                var featureMarker = createMarker(
                  coords[1], // latitude
                  coords[0], // longitude
                  feature.properties.color || markerCoordinate.color,
                  feature.properties.fa_icon_class || markerCoordinate.fa_icon_class
                );

                featureMarker.options.id = markerCoordinate.id
                featureMarker.options.resource_type = markerCoordinate.resource_type
                featureMarker.options.projekt_phase_id = markerCoordinate.projekt_phase_id

                if ( App.MapPopup.excludedProcesses.indexOf(process) == -1 ) {
                  featureMarker.on("click", openMarkerPopup);
                }
              } else {
                // Render non-Point features as geoJSON layers
                if (Object.keys(feature).length) {
                  var userShape = L.geoJSON(feature, {
                    style: function(geoFeature) {
                      return {
                        color: geoFeature.properties.color || markerCoordinate.color || feature.properties.color || App.Utils.getBrandColor()
                      };
                    }
                  });
                }

                userShape.options.id = markerCoordinate.id
                userShape.options.resource_type = markerCoordinate.resource_type
                userShape.options.projekt_phase_id = markerCoordinate.projekt_phase_id

                if ( App.MapPopup.excludedProcesses.indexOf(process) == -1 ) {
                  userShape.on("click", openMarkerPopup);
                }
                userShape.addTo(deflateFeatures);
                userShape.addTo(map);
              }
            });
          } else {
            // Handle single GeoJSON feature or legacy format
            if (Object.keys(markerCoordinate).length) {
              var userShape = L.geoJSON(markerCoordinate, {
                style: function(feature) {
                  return { color: (markerCoordinate.color || App.Utils.getBrandColor()) };
                }
              });

              userShape.options.id = markerCoordinate.id
              userShape.options.resource_type = markerCoordinate.resource_type
              userShape.options.projekt_phase_id = markerCoordinate.projekt_phase_id

              if ( App.MapPopup.excludedProcesses.indexOf(process) == -1 ) {
                userShape.on("click", openMarkerPopup);
              }
              userShape.addTo(deflateFeatures);
              userShape.addTo(map);
            }
          }
        });
      }
      /* Assembles a map: end */


      /* Leaflet-Geoman plugin: config start */
      // configure editor controls
      if ( editable ) {

        // sets default language to German
        map.pm.setLang('de');

        // set positions for geoman controls
        map.pm.Toolbar.setBlockPosition('draw', 'topright');
        map.pm.Toolbar.setBlockPosition('edit', 'topright');

        // remove unnecessary controls
        map.pm.addControls({
          drawMarker: false,
          drawCircleMarker: false,
          drawText: false,
          removalMode: false
        });
        if ( !enableGeomanControls ) {
          map.pm.addControls({
            drawPolyline: false,
            drawRectangle: false,
            drawPolygon: false,
            drawCircle: false,
            editMode: false,
            dragMode: false,
            cutPolygon: false,
            rotateMode: false,
            oneBlock: true
          })
        }

        // add consul marker to geoman controls
        if ( enableGeomanControls ) {
          map.pm.Toolbar.createCustomControl({
            name: 'consulMarker',
            className: 'control-icon leaflet-pm-icon-marker',
            title: 'Marker setzen',
            block: 'draw',
            onClick: function() {
              // Only clear markers when turning ON the tool (not admin editor) or when explicitly requested
              if (!this.toggleStatus && !adminEditor) {
                removeShapesAndMarkers();
              }

              if (this.toggleStatus) {
                map.off("click", moveOrPlaceMarker);
              } else {
                map.on("click", moveOrPlaceMarker);
              }
            }
          });
        }

        // add remove consul marker to geoman controls
        map.pm.Toolbar.createCustomControl({
          name: 'clearMap',
          className: 'control-icon leaflet-pm-icon-delete',
          title: 'Karte zurücksetzen',
          block: 'edit',
          onClick: function() {
            removeShapesAndMarkers();
            if ( enableGeomanControls ) {
              map.pm.Toolbar.toggleButton('clearMap', true);
              map.off("click", moveOrPlaceMarker);
            } else {
              map.pm.Toolbar.toggleButton('clearMap', false);
              map.pm.Toolbar.toggleButton('consulMarker', true);
              map.on("click", moveOrPlaceMarker);
            }
          },
          afterClick: function() {
            if (!enableGeomanControls) {
              $(".control-icon.leaflet-pm-icon-delete").closest(".active").removeClass("active")
            }

            // Don't clear latitude and longitude fields, only clear shape data
            $(shapeInputSelector).val(JSON.stringify({}));

            if (adminEditor) {
              $(showAdminShapeInputSelector).val(false);
            }
          }
        });

        // toggle consul marker button by default for regular users
        if ( !adminEditor ) {
          map.pm.Toolbar.toggleButton('consulMarker', true)
          map.on("click", moveOrPlaceMarker);
        }

        // reorder geoman controls
        map.pm.Toolbar.changeControlOrder([
          'consulMarker'
        ]);

        // set colors of shapes for admin
        if ( adminEditor ) {
          map.pm.setPathOptions({
            color: adminShapesColor,
            fillColor: adminShapesColor,
            fillOpacity: 0.4
          });
          map.pm.setGlobalOptions({
            templineStyle: { color: adminShapesColor },
            hintlineStyle: { color: adminShapesColor, dashArray: [5, 5]  }
          })
        }

              // remove past elements when new element is started, except for cutting
      map.on('pm:drawstart', function(e) {
        if (e.shape == 'Cut') {
          return
        }
        // Only remove existing elements if not in admin editor mode
        if (!adminEditor) {
          removeShapesAndMarkers();
        }
      });

        // function to clear previously created shapes (only one shaped allowed)
        function removeShapesAndMarkers() {
          if (marker) {
            map.removeLayer(marker);
            marker = null;
          }

          map.pm.getGeomanLayers().forEach(function(layer) {
            if ( layer.pm.options.adminShape != true || adminEditor ) {
              layer.remove();
            }
          })

          // Clear shape data but preserve latitude and longitude
          $(shapeInputSelector).val(JSON.stringify({}));

          if (!adminEditor) {
            $(showAdminShapeInputSelector).val(false);
          }
        }

        // add newly created shape to form field
        map.on('pm:create', function(e) {
          var layer = e.layer;

          if (e.shape == 'Circle') {
            layer.options.shape = 'Circle'
          }

          updateShapeFieldInForm(layer);
          addEventListenersToShapeLayer(layer)
        })

        // Handle shape deletion in admin mode
        map.on('pm:remove', function(e) {
          if (adminEditor) {
            // Update form fields after deletion
            setTimeout(function() {
              updateShapeFieldInForm(null);
            }, 10);
          }
        })

        // update shape field in form
        var updateShapeFieldInForm = function(layer) {
          if (layer.options.shape == 'Circle') {
            layer = L.PM.Utils.circleToPolygon(layer, 60)
          }

          $(latitudeInputSelector).val(map.getCenter().lat);
          $(longitudeInputSelector).val(map.getCenter().lng);
          $(zoomInputSelector).val(map.getZoom());

          if (adminEditor) {
            // For admin editor, collect all shapes and markers
            var allFeatures = [];

            // Collect all drawn shapes
            map.pm.getGeomanLayers().forEach(function(geomanLayer) {
              if (geomanLayer.pm.options.adminShape != true) {
                var layerCopy = geomanLayer;
                if (geomanLayer.options.shape == 'Circle') {
                  layerCopy = L.PM.Utils.circleToPolygon(geomanLayer, 60);
                }
                var feature = layerCopy.toGeoJSON();
                feature.properties = feature.properties || {};
                feature.properties.color = adminShapesColor;
                feature.properties.fa_icon_class = 'circle';
                allFeatures.push(feature);
              }
            });

            // Create FeatureCollection for multiple features
            var featureCollection = {
              type: 'FeatureCollection',
              features: allFeatures
            };

            $(shapeInputSelector).val(JSON.stringify(featureCollection));
            $(showAdminShapeInputSelector).val(true);
          } else {
            // For regular users, single shape only
            var shape = layer.toGeoJSON();
            var shapeString = JSON.stringify(shape);
            $(shapeInputSelector).val(shapeString);
          }
        };
      }
      /* Leaflet-Geoman plugin: config start */
    },

    validCoordinates: function(coordinates) {
      return App.Map.isNumeric(coordinates.lat) && App.Map.isNumeric(coordinates.long);
    },

    isNumeric: function(n) {
      return !isNaN(parseFloat(n)) && isFinite(n);
    }
  };
}).call(this);

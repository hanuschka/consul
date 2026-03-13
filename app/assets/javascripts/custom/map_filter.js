(function() {
  "use strict";

  class MapFilter {
    constructor() {
      this.resourcesList = document.querySelector(".js-map-resources-list");
      this.loadingIndicator = document.querySelector(".js-map-resources-loading");
      this.resourceCount = document.querySelector(".js-map-resource-count");
      this.clearFiltersButton = document.querySelector(".js-clear-all-filters");
      this.resetViewButton = document.querySelector(".js-reset-view");
      this.mapInstance = null;
      this.debounceTimer = null;
      this.debounceDelay = 300;

      this.initialize();
      MapFilter.instance = this;
    }

    initialize() {
      this.findMapInstance();

      var self = this;
      if (this.clearFiltersButton) {
        this.clearFiltersButton.addEventListener("click", function() {
          self.clearAllFilters();
        });
      }

      if (this.resetViewButton) {
        this.resetViewButton.addEventListener("click", function() {
          self.resetMapView();
        });
      }

      $(document).on("ajax:success", ".map-page--header-filters a[data-remote='true']", function() {
        self.handleFilterChange();
      });
    }

    findMapInstance() {
      if (window.App && window.App.Mapbox && App.Mapbox.maps && App.Mapbox.maps.length > 0) {
        this.mapInstance = App.Mapbox.maps[0];
      } else if (window.App && window.App.Map && App.Map.maps && App.Map.maps.length > 0) {
        this.mapInstance = App.Map.maps[0];
      }
    }

    handleFilterChange() {
      var self = this;
      
      clearTimeout(this.debounceTimer);
      this.debounceTimer = setTimeout(function() {
        self.applyFilters();
      }, this.debounceDelay);
    }

    getActiveFilters() {
      var filterTypes = [];
      var urlParams = new URLSearchParams(window.location.search);
      
      var filterPlatform = urlParams.get("filter_platform");
      if (filterPlatform && filterPlatform !== "all") {
        switch(filterPlatform) {
          case "projekt":
            filterTypes.push("Projekt");
            break;
          case "budget":
            filterTypes.push("Budget::Investment");
            break;
          case "proposal":
            filterTypes.push("Proposal");
            break;
          case "point_of_interest":
            filterTypes.push("ProjektPointOfInterestPin");
            break;
          case "deficiency_report":
            filterTypes.push("DeficiencyReport");
            break;
          case "idea":
            filterTypes.push("Idea");
            break;
        }
      }

      return filterTypes;
    }

    applyFilters() {
      var self = this;
      var filterTypes = this.getActiveFilters();

      this.showLoading();

      var urlParams = new URLSearchParams(window.location.search);
      urlParams.set("filter_types", filterTypes.join(","));

      $.ajax({
        url: window.location.pathname + "?" + urlParams.toString(),
        type: "GET",
        dataType: "script",
        error: function(xhr, status, error) {
          console.error("Error filtering map:", error);
          self.hideLoading();
          self.showError();
        }
      });
    }

    clearAllFilters() {
      window.location.href = "/map";
    }

    resetMapView() {
      if (this.mapInstance && this.mapInstance.map) {
        if (this.mapInstance.map.setView) {
          var defaultLat = parseFloat(this.mapInstance.mapCenterLatitude) || 51.1657;
          var defaultLng = parseFloat(this.mapInstance.mapCenterLongitude) || 10.4515;
          var defaultZoom = parseFloat(this.mapInstance.zoom) || 6;
          this.mapInstance.map.setView([defaultLat, defaultLng], defaultZoom);
        } else if (this.mapInstance.map.jumpTo) {
          var defaultLat = parseFloat(this.mapInstance.mapCenterLatitude) || 51.1657;
          var defaultLng = parseFloat(this.mapInstance.mapCenterLongitude) || 10.4515;
          var defaultZoom = parseFloat(this.mapInstance.zoom) || 6;
          this.mapInstance.map.jumpTo({
            center: [defaultLng, defaultLat],
            zoom: defaultZoom
          });
        }
      }
    }

    updateMap(features) {
      if (!this.mapInstance) {
        this.findMapInstance();
      }

      if (!this.mapInstance) {
        console.warn("Map instance not found");
        return;
      }

      if (this.mapInstance.map && this.mapInstance.map.getSource) {
        this.updateMapboxMap(features);
      } else if (this.mapInstance.map && this.mapInstance.map.eachLayer) {
        this.updateLeafletMap(features);
      }
    }

    updateMapboxMap(features) {
      var source = this.mapInstance.map.getSource("marker-coordinates");
      if (!source) {
        console.warn("Marker source not found");
        return;
      }

      var featuresGeoJSON = this.convertFeaturesToGeoJSON(features);
      source.setData(featuresGeoJSON);
    }

    updateLeafletMap(features) {
      var self = this;
      var map = this.mapInstance.map;

      if (this.mapInstance.clusterGroup) {
        this.mapInstance.clusterGroup.clearLayers();
      }
      if (this.mapInstance.deflateFeatures) {
        this.mapInstance.deflateFeatures.clearLayers();
      }

      if (features && features.length > 0) {
        features.forEach(function(featureData) {
          if (featureData.features && Array.isArray(featureData.features)) {
            featureData.features.forEach(function(feature) {
              if (feature.geometry && feature.geometry.type === "Point") {
                var latlng = [feature.geometry.coordinates[1], feature.geometry.coordinates[0]];
                var markerTitle = feature.properties.feature_category_name || feature.properties.title || "Kartenmarkierung";
                var marker = L.marker(latlng, {
                  icon: App.Utils.getLeafletMarkerHTML(
                    feature.properties.feature_color || self.mapInstance.defaultFeatureColor,
                    feature.properties.feature_icon_name,
                    markerTitle
                  )
                });

                if (self.mapInstance.clusterGroup) {
                  self.mapInstance.clusterGroup.addLayer(marker);
                }

                if (self.mapInstance.process && App.MapPopup.excludedProcesses.indexOf(self.mapInstance.process) === -1) {
                  marker.options.resource_type = feature.properties.resource_type || null;
                  marker.options.id = feature.properties.id || null;
                  marker.on("click", self.mapInstance.openMarkerPopup);
                }
              }
            });
          }
        });
      }
    }

    convertFeaturesToGeoJSON(features) {
      var geoJSONFeatures = [];

      if (!features || !Array.isArray(features)) {
        return {
          type: "FeatureCollection",
          features: []
        };
      }

      features.forEach(function(featureData) {
        if (featureData.features && Array.isArray(featureData.features)) {
          featureData.features.forEach(function(feature) {
            if (feature.geometry && feature.geometry.type === "Point") {
              geoJSONFeatures.push({
                type: "Feature",
                id: feature.properties.id,
                geometry: feature.geometry,
                properties: {
                  id: feature.properties.id,
                  resource_type: feature.properties.resource_type,
                  color: feature.properties.feature_color,
                  fa_icon_class: feature.properties.feature_icon_name || "circle"
                }
              });
            }
          });
        }
      });

      return {
        type: "FeatureCollection",
        features: geoJSONFeatures
      };
    }

    updateSidebarHtml(html) {
      if (!this.resourcesList) return;

      if (!html || html.trim() === "") {
        this.resourcesList.innerHTML = '<p class="map-resources-empty">' + 
          (window.I18n && I18n.t ? I18n.t("custom.map.index.no_resources") : "Keine Ressourcen gefunden") + 
          '</p>';
        return;
      }

      this.resourcesList.innerHTML = html;
    }

    updateResourceCount(count) {
      if (this.resourceCount) {
        var countText = count + " " + (window.I18n && I18n.t ? I18n.t("custom.map.index.resources_found", { count: count }) : "Ressourcen gefunden");
        this.resourceCount.textContent = countText;
      }
    }

    showLoading() {
      if (this.loadingIndicator) {
        this.loadingIndicator.style.display = "block";
      }
      if (this.resourcesList) {
        this.resourcesList.style.opacity = "0.5";
      }
    }

    hideLoading() {
      if (this.loadingIndicator) {
        this.loadingIndicator.style.display = "none";
      }
      if (this.resourcesList) {
        this.resourcesList.style.opacity = "1";
      }
    }

    showError() {
      if (this.resourcesList) {
        this.resourcesList.innerHTML = '<p class="map-resources-error">' +
          (window.I18n && I18n.t ? I18n.t("custom.map.index.error") : "Fehler beim Laden der Daten") +
          '</p>';
      }
    }
  }

  App.MapFilter = MapFilter;

  document.addEventListener("turbolinks:load", function() {
    if (document.querySelector(".map-page")) {
      new MapFilter();
    }
  });
}).call(this);

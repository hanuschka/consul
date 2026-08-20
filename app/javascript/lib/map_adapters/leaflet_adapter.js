import BaseAdapter from "./base_adapter"
import { getBrandColor, MapPopup, numberOrDefault } from "./map_utils"

/**
 * Leaflet Map Adapter
 *
 * Implements the BaseAdapter interface for Leaflet maps.
 * Scripts are loaded asynchronously on first use.
 */
export default class LeafletAdapter extends BaseAdapter {
  static scriptsLoaded = false
  static scriptsLoading = false
  static loadQueue = []
  static searchCountryCodes = "de"
  static searchBiasDegrees = 0.3

  // ===========================================================================
  // 1. INITIALIZATION & CONFIGURATION
  // ===========================================================================

  initialize(container, options) {
    this.container = container
    this.options = options
    this.adminEditor = options.adminEditor || false
    this.masterportalEnabled = options.masterportalEnabled || false
    this.masterportalDefaultIconUrl = options.masterportalDefaultIconUrl || null
    this.defaultFeatureColor = this.getDefaultFeatureColor(this.adminEditor)
    this.featuresLimit = options.featuresLimit || 1
    this.clusterGroup = null
    this.deflateFeatures = null
    this._geojsonLegends = []

    return this.loadScripts().then(() => {
      this.createMap(container, options)
      this.setupExpandControl()
      this.addResetViewControl()
      this.setupPlugins()
      this.configureGeoman()
    })
  }

  destroy() {
    if (this._geojsonLegends) {
      this._geojsonLegends.forEach(legend => legend.remove())
      this._geojsonLegends = []
    }
    if (this.map) {
      this.map.off()
      this.map.remove()
      this.map = null
    }
    this.editableLayers = []
    this.baseLayers = {}
    this.overlayLayers = {}
  }

  /**
   * Load Leaflet and all plugins asynchronously
   */
  loadScripts() {
    return new Promise((resolve) => {
      if (LeafletAdapter.scriptsLoaded) {
        resolve()
        return
      }

      LeafletAdapter.loadQueue.push(resolve)

      if (LeafletAdapter.scriptsLoading) return

      LeafletAdapter.scriptsLoading = true

      const cssUrls = [
        "https://unpkg.com/leaflet@1.9.4/dist/leaflet.css",
        "https://unpkg.com/@geoman-io/leaflet-geoman-free@2.16.0/dist/leaflet-geoman.css",
        "https://unpkg.com/leaflet-geosearch@3.11.1/dist/geosearch.css",
        "https://unpkg.com/leaflet.locatecontrol@0.81.1/dist/L.Control.Locate.min.css",
        "https://unpkg.com/leaflet-gesture-handling@1.2.2/dist/leaflet-gesture-handling.min.css",
        "https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.css",
        "https://unpkg.com/leaflet.markercluster@1.5.3/dist/MarkerCluster.Default.css"
      ]

      cssUrls.forEach(url => {
        if (!document.querySelector(`link[href="${url}"]`)) {
          const link = document.createElement("link")
          link.rel = "stylesheet"
          link.href = url
          document.head.appendChild(link)
        }
      })

      const jsUrls = [
        "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js",
        "https://unpkg.com/@geoman-io/leaflet-geoman-free@2.16.0/dist/leaflet-geoman.js",
        "https://unpkg.com/leaflet-geosearch@3.11.1/dist/bundle.min.js",
        "https://unpkg.com/leaflet.locatecontrol@0.81.1/dist/L.Control.Locate.min.js",
        "https://unpkg.com/leaflet-gesture-handling@1.2.2/dist/leaflet-gesture-handling.min.js",
        "https://unpkg.com/leaflet.markercluster@1.5.3/dist/leaflet.markercluster.js",
        "https://cdn.jsdelivr.net/npm/Leaflet.Deflate@1.0.0-alpha.3/dist/L.Deflate.min.js"
      ]

      const loadNext = (index) => {
        if (index >= jsUrls.length) {
          LeafletAdapter.scriptsLoaded = true
          LeafletAdapter.loadQueue.forEach(cb => cb())
          LeafletAdapter.loadQueue = []
          return
        }

        const script = document.createElement("script")
        script.src = jsUrls[index]
        script.async = false
        script.onload = () => loadNext(index + 1)
        script.onerror = () => {
          console.error(`Failed to load: ${jsUrls[index]}`)
          loadNext(index + 1)
        }
        document.head.appendChild(script)
      }

      loadNext(0)
    })
  }

  // ===========================================================================
  // 2. MAP CREATION & CONTROLS
  // ===========================================================================

  createMap(container, options) {
    const L = window.L
    const center = [options.latitude, options.longitude]

    this.initialCenter = center
    this.initialZoom = options.zoom

    this.map = L.map(container, {
      gestureHandling: options.gestureHandling !== false,
      maxZoom: window.App.MapZoom.MAX,
      zoomControl: false
    }).setView(center, options.zoom)

    L.control.zoom({
      zoomInTitle: "Hineinzoomen",
      zoomOutTitle: "Herauszoomen"
    }).addTo(this.map)
  }

  setupExpandControl() {
    const L = window.L
    const instance = this

    const ExpandControl = L.Control.extend({
      options: { position: "topright" },

      onAdd(map) {
        const container = L.DomUtil.create("div", "leaflet-bar leaflet-control")
        const button = L.DomUtil.create("a", "leaflet-control-expand", container)
        button.innerHTML = '<span class="material-symbols-outlined">fullscreen</span>'
        button.href = "#"
        button.title = "Vollbild-Modus"
        button.role = "button"

        L.DomEvent.disableClickPropagation(container)
        L.DomEvent.on(button, "click", L.DomEvent.preventDefault)
        L.DomEvent.on(button, "click", () => {
          const mapContainer = instance.container
          if (mapContainer.classList.contains("expanded")) {
            mapContainer.classList.remove("expanded")
            button.innerHTML = '<span class="material-symbols-outlined">fullscreen</span>'
          } else {
            mapContainer.classList.add("expanded")
            button.innerHTML = '<span class="material-symbols-outlined">fullscreen_exit</span>'
          }
          map.invalidateSize()
          instance.toggleControlVisibility()
        })

        return container
      }
    })

    new ExpandControl().addTo(this.map)
  }

  addResetViewControl() {
    const L = window.L
    const instance = this

    const ResetViewControl = L.Control.extend({
      options: { position: "topright" },

      onAdd() {
        const container = L.DomUtil.create("div", "leaflet-bar leaflet-control")
        const button = L.DomUtil.create("a", "leaflet-control-reset-view", container)
        button.innerHTML = '<span class="material-symbols-outlined">home</span>'
        button.href = "#"
        button.title = "Ansicht zurücksetzen"
        button.role = "button"

        L.DomEvent.disableClickPropagation(container)
        L.DomEvent.on(button, "click", L.DomEvent.preventDefault)
        L.DomEvent.on(button, "click", () => {
          instance.map.setView(instance.initialCenter, instance.initialZoom, { animate: true })
        })

        return container
      }
    })

    new ResetViewControl().addTo(this.map)
  }

  toggleControlVisibility() {
    const controls = [
      this.container.querySelector(".leaflet-control-layers"),
      this.container.querySelector(".leaflet-control-locate"),
      this.container.querySelector(".leaflet-control-geosearch")
    ]

    const isSmall = this.container.offsetWidth < 700
    controls.forEach(control => {
      if (control) control.style.display = isSmall ? "none" : ""
    })
  }

  // ===========================================================================
  // 3. LAYER MANAGEMENT
  // ===========================================================================

  setupLayers(layers) {
    const L = window.L

    if (layers && layers.length > 0) {
      layers.forEach(item => this.createLayer(item))
    }

    this.ensureBaseLayerExists()
    this.baseLayers[Object.keys(this.baseLayers)[0]].addTo(this.map)

    // Add overlay layers that should be visible by default
    Object.keys(this.overlayLayers).forEach(key => {
      if (this.overlayLayers[key].options.show_by_default) {
        this.overlayLayers[key].addTo(this.map)
      }
    })

    this.addLayerControl()
  }

  createLayer(item) {
    const L = window.L
    const zoomLimits = window.App.MapZoom
    let layer

    if (item.protocol === "wms") {
      layer = L.tileLayer.wms(item.provider, {
        attribution: item.attribution,
        layers: item.layer_names,
        format: item.transparent ? "image/png" : "image/jpeg",
        transparent: item.transparent,
        show_by_default: item.show_by_default,
        opacity: item.opacity || 1,
        maxZoom: zoomLimits.MAX
      })
    } else if (item.protocol === "geojson") {
      layer = this.createGeoJsonOverlay(item)
    } else {
      layer = L.tileLayer(item.provider, {
        attribution: item.attribution,
        maxZoom: zoomLimits.MAX,
        maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
      })
    }

    if (item.base) {
      this.baseLayers[item.name] = layer
    } else {
      this.overlayLayers[item.name] = layer
    }
  }

  // Build a lazy-loading GeoJSON overlay. The layer group fetches and renders
  // its data the first time it is added to the map (either by default or via
  // the layer control). Returns the group so createLayer can register it as an
  // overlay (geojson layers are never base layers).
  createGeoJsonOverlay(item) {
    const L = window.L
    const group = L.layerGroup()

    group.options.show_by_default = item.show_by_default
    group._geojsonLoaded = false
    group._mapLayerItem = item

    group.on("add", () => {
      if (!group._geojsonLoaded) {
        group._geojsonLoaded = true
        this.loadGeoJsonInto(group, item)
      }
    })

    return group
  }

  loadGeoJsonInto(group, item) {
    fetch(item.data_url)
      .then(response => response.json())
      .then(data => {
        const L = window.L
        const cfg = item.config || {}

        // Overlays are non-interactive: an interactive Leaflet canvas layer blocks
        // map dragging everywhere except directly on a feature. pmIgnore keeps
        // Geoman from treating the overlay as an editable shape.
        const gj = L.geoJSON(data, {
          renderer: L.canvas({ padding: 0.5 }),
          interactive: false,
          pmIgnore: true,
          style: (feature) => this.geoJsonStyle(feature, cfg)
        })

        gj.addTo(group)

        if (cfg.choropleth && cfg.choropleth.enabled) {
          this.addChoroplethLegend(cfg)
        }
      })
      .catch(err => console.error("Failed to load GeoJSON layer", item.name, err))
  }

  geoJsonStyle(feature, cfg) {
    const style = cfg.style || {}

    let fillColor = style.fillColor || "#3366CC"
    const fillOpacity = numberOrDefault(style.fillOpacity, 0.3)
    const color = style.color || "#1A3C8C"
    const weight = numberOrDefault(style.weight, 1)

    if (cfg.choropleth && cfg.choropleth.enabled) {
      fillColor = this.choroplethColor(feature.properties[cfg.choropleth.property], cfg.choropleth)
    }

    return { fillColor, fillOpacity, color, weight }
  }

  choroplethColor(value, ch) {
    const v = parseFloat(value)
    if (isNaN(v)) return ch.no_data_color || "#cccccc"

    const breaks = ch.breaks || []
    const colors = ch.colors || []

    let i = 0
    while (i < breaks.length && v >= parseFloat(breaks[i])) i++

    return colors[i] || colors[colors.length - 1] || "#cccccc"
  }

  addChoroplethLegend(cfg) {
    const L = window.L
    const ch = cfg.choropleth || {}
    const breaks = ch.breaks || []
    const colors = ch.colors || []

    const legend = L.control({ position: "bottomright" })

    legend.onAdd = () => {
      const container = L.DomUtil.create("div", "leaflet-control-attribution map-choropleth-legend")
      const rows = []

      if (ch.legend_title) {
        rows.push(`<div class="map-choropleth-legend__title"><strong>${MapPopup.escapeHtml(ch.legend_title)}</strong></div>`)
      }

      for (let i = 0; i < colors.length; i++) {
        let label
        if (i === 0) {
          label = `< ${MapPopup.escapeHtml(breaks[0])}`
        } else if (i === colors.length - 1) {
          label = `≥ ${MapPopup.escapeHtml(breaks[breaks.length - 1])}`
        } else {
          label = `${MapPopup.escapeHtml(breaks[i - 1])} – ${MapPopup.escapeHtml(breaks[i])}`
        }

        const swatch = `<span class="map-choropleth-legend__swatch" style="display:inline-block;width:14px;height:14px;margin-right:6px;background:${MapPopup.escapeHtml(colors[i])}"></span>`
        rows.push(`<div class="map-choropleth-legend__row">${swatch}${label}</div>`)
      }

      container.innerHTML = rows.join("")
      return container
    }

    legend.addTo(this.map)
    this._geojsonLegends.push(legend)
  }

  ensureBaseLayerExists() {
    const L = window.L
    const zoomLimits = window.App.MapZoom

    if (Object.keys(this.baseLayers).length === 0) {
      this.baseLayers["OpenStreetMap"] = L.tileLayer(
        "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
        {
          attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors',
          maxZoom: zoomLimits.MAX,
          maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
        }
      )
    }
  }

  addLayerControl() {
    const L = window.L
    const hasMultipleBaseLayers = Object.keys(this.baseLayers).length > 1
    const hasOverlayLayers = Object.keys(this.overlayLayers).length > 0

    if (hasMultipleBaseLayers && hasOverlayLayers) {
      L.control.layers(this.baseLayers, this.overlayLayers).addTo(this.map)
    } else if (hasOverlayLayers) {
      L.control.layers({}, this.overlayLayers).addTo(this.map)
    }
  }

  // ===========================================================================
  // 4. PLUGINS & ADDITIONAL CONTROLS
  // ===========================================================================

  setupPlugins() {
    this.addLocateControl()
    this.addSearchControl()
    this.setupClustering()
  }

  addLocateControl() {
    const L = window.L

    L.control.locate({
      icon: "material-symbols-outlined",
      iconLoading: "material-symbols-outlined",
      iconElementTag: "span",
      createButtonCallback: (container, options) => {
        const link = L.DomUtil.create("a", "leaflet-bar-part leaflet-bar-part-single", container)
        link.title = options.strings.title
        const icon = L.DomUtil.create(options.iconElementTag, options.icon, link)
        icon.textContent = "my_location"
        return { link, icon }
      },
      strings: { title: "Meine Position anzeigen" }
    }).addTo(this.map)
  }

  addSearchControl() {
    const L = window.L
    const GeoSearch = window.GeoSearch

    const provider = new GeoSearch.OpenStreetMapProvider({
      params: { countrycodes: LeafletAdapter.searchCountryCodes }
    })

    this.updateSearchViewbox(provider)
    this.map.on("moveend", () => this.updateSearchViewbox(provider))

    const searchControl = new GeoSearch.GeoSearchControl({
      provider: provider,
      style: "bar",
      showMarker: false,
      searchLabel: "Nach Adresse suchen",
      notFoundMessage: "Entschuldigung! Die Adresse wurde nicht gefunden.",
      clearSearchLabel: "Suche zurücksetzen"
    })
    this.map.addControl(searchControl)

    const searchInput = this.container.querySelector('.leaflet-control-geosearch input[type="text"]')
    if (searchInput) {
      searchInput.setAttribute("title", "Nach Adresse suchen")
      searchInput.setAttribute("aria-label", "Nach Adresse suchen")
    }
  }

  updateSearchViewbox(provider) {
    const center = this.map.getCenter()
    const latitudeDelta = LeafletAdapter.searchBiasDegrees
    const longitudeDelta = latitudeDelta / Math.max(Math.cos(center.lat * Math.PI / 180), 0.1)

    provider.options.params.viewbox = [
      center.lng - longitudeDelta,
      center.lat + latitudeDelta,
      center.lng + longitudeDelta,
      center.lat - latitudeDelta
    ].map((coordinate) => coordinate.toFixed(6)).join(",")
  }

  setupClustering() {
    const L = window.L

    this.clusterGroup = L.markerClusterGroup({ removeOutsideVisibleBounds: false })
    this.clusterGroup.addTo(this.map)

    // L.deflate may not be available if the plugin failed to load
    if (typeof L.deflate === "function") {
      this.deflateFeatures = L.deflate({
        minSize: 30,
        markerLayer: this.clusterGroup,
        markerOptions: (shape) => ({
          icon: this.createMarkerIcon(
            shape.feature?.properties?.color || this.defaultFeatureColor,
            shape.feature?.properties?.feature_icon_name,
            null,
            shape.feature
          )
        })
      })
      this.deflateFeatures.addTo(this.map)
    }
  }

  // ===========================================================================
  // 5. FEATURE RENDERING
  // ===========================================================================

  addFeatures(features, options = {}) {
    if (!features || Object.keys(features).length === 0) return

    const L = window.L
    const editable = options.editable === true
    const instance = this

    L.geoJSON(features, {
      pointToLayer(feature, latlng) {
        const color = instance.adminEditor ? "#ff0000" :
                      feature.properties?.feature_color ||
                      feature.properties?.color ||
                      instance.defaultFeatureColor
        var markerTitle = feature.properties?.feature_category_name || "Kartenmarkierung"
        return L.marker(latlng, {
          icon: instance.createMarkerIcon(color, feature.properties?.feature_icon_name, markerTitle, feature)
        })
      },

      style(feature) {
        const color = instance.adminEditor ? "#ff0000" :
                      feature.properties?.feature_color ||
                      feature.properties?.color ||
                      instance.defaultFeatureColor
        return {
          weight: 2,
          color: color,
          fillColor: color,
          fillOpacity: 0.2
        }
      },

      onEachFeature(feature, layer) {
        if (editable) {
          layer.addTo(instance.map)
          instance.setupEditableFeatureListeners(layer)
          instance.editableLayers.push(layer)

          layer.on("pm:edit", () => {
            if (instance.callbacks.onEdit) instance.callbacks.onEdit()
          })
        } else {
          // Read-only mode: add to cluster/deflate
          if (feature.geometry.type === "Point") {
            instance.clusterGroup.addLayer(layer)
          } else if (instance.deflateFeatures) {
            instance.deflateFeatures.addLayer(layer)
          } else {
            instance.clusterGroup.addLayer(layer)
          }

          // Set up popup click handler
          layer.options.resource_type = feature.properties?.resource_type || null
          layer.options.id = feature.properties?.id || null
          layer.options.feature_color = feature.properties?.feature_color || instance.defaultFeatureColor
          layer.options.feature_icon_name = feature.properties?.feature_icon_name || "circle"
          layer.options.feature_category_name = feature.properties?.feature_category_name || null
          layer.options.feature_popup_template = feature.properties?.feature_popup_template || null
          layer.options.feature = feature

          layer.on("click", (e) => instance.openFeaturePopup(e))
        }
      }
    })
  }

  addAdminFeatures(features) {
    if (!features || Object.keys(features).length === 0) return

    const L = window.L
    const instance = this

    const adminLayer = L.geoJSON(features, {
      pointToLayer(feature, latlng) {
        return L.marker(latlng, { icon: instance.createMarkerIcon("#ff0000") })
      },
      style: {
        color: "#ff0000",
        weight: 2,
        fillOpacity: 0.2
      },
      onEachFeature(feature, layer) {
        layer.bindPopup('<div class="map-popup-status-message">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>')
        layer.pm.disable()
        layer.pm.setOptions({ draggable: false, editable: false })
      }
    }).addTo(this.map)

    this.overlayLayers["Verwaltungseinträge"] = adminLayer
    this.renderAdminFeaturesNote()
  }

  renderAdminFeaturesNote() {
    const L = window.L

    const adminNote = L.control({ position: "bottomleft" })
    adminNote.onAdd = () => {
      const container = L.DomUtil.create("div", "leaflet-control-attribution")
      container.innerHTML = "Alle markierten Flächen und Pins in rot sind vom System vorgegeben"
      container.style.color = "#ff0000"
      return container
    }
    adminNote.addTo(this.map)
  }

  createMarkerIcon(color, iconName, title, feature) {
    const L = window.L

    if (feature && feature.properties && feature.properties.feature_icon_url) {
      return this.masterportalImageIcon(feature.properties.feature_icon_url)
    }

    if (this.isMasterportalFeature(feature)) {
      const dotColor = (feature && feature.properties && feature.properties.feature_color) ||
                       this.defaultFeatureColor
      return this.masterportalDotIcon(dotColor)
    }

    color = color || getBrandColor()
    iconName = iconName || "circle"
    title = title || "Kartenmarkierung"

    return L.divIcon({
      className: "map-marker",
      iconSize: [30, 30],
      iconAnchor: [15, 40],
      html: `<div class="map-icon icon-${iconName}" role="img" aria-label="${title}" title="${title}" style="background-color: ${color}"></div>`
    })
  }

  isMasterportalFeature(feature) {
    if (!feature || !feature.properties) return false

    return this.masterportalEnabled || feature.properties.resource_type === "masterportal_pin"
  }

  masterportalImageIcon(iconUrl) {
    const L = window.L

    return L.icon({
      iconUrl: encodeURI(iconUrl),
      iconSize: [36, 36],
      iconAnchor: [18, 18],
      popupAnchor: [0, -18]
    })
  }

  // Masterportal pins without a custom image render as a colored dot (pins are
  // reserved for user resources); the color comes from the collection color.
  masterportalDotIcon(color) {
    const L = window.L
    const title = "Masterportal-Pin"
    const size = 20
    const half = size / 2

    return L.divIcon({
      className: "masterportal-dot-marker",
      iconSize: [size, size],
      iconAnchor: [half, half],
      popupAnchor: [0, -half],
      html: `<span role="img" aria-label="${title}" title="${title}" style="background-color: ${color}"></span>`
    })
  }

  openFeaturePopup(e) {
    const layer = e.target
    const popupOptions = { autoPanPadding: [0, 80], minWidth: 200, offset: window.L.point(0, -30) }

    const resourceType = layer.options.resource_type
    const properties = {
      id: layer.options.id,
      feature_color: layer.options.feature_color,
      feature_icon_name: layer.options.feature_icon_name,
      feature_category_name: layer.options.feature_category_name
    }

    const route = MapPopup.getPopupDataUrl(resourceType, properties)
    if (!route) return

    fetch(route)
      .then(response => response.json())
      .then(data => {
        const finalOptions = Object.assign({}, popupOptions)

        if (resourceType === "masterportal_pin") {
          finalOptions.className = "masterportal-popup-wrapper"
          finalOptions.minWidth = 260
          finalOptions.maxWidth = 360
          finalOptions.offset = window.L.point(0, 0)
        }

        layer.bindPopup(
          MapPopup.generatePopupContent(data, resourceType, properties),
          finalOptions
        ).openPopup()
      })
  }

  // ===========================================================================
  // 6. EDITING CONTROLS
  // ===========================================================================

  enableEditing(options = {}) {
    const enableShapes = options.enableShapes !== false

    this.configureGeoman()

    this.map.pm.Toolbar.setBlockPosition("custom", "topright")
    this.map.pm.Toolbar.setBlockPosition("draw", "topright")
    this.map.pm.Toolbar.setBlockPosition("edit", "topright")

    this.map.pm.addControls({
      drawCircleMarker: false,
      drawText: false,
      removalMode: false,
      drawPolyline: enableShapes,
      drawRectangle: enableShapes,
      drawPolygon: enableShapes,
      drawCircle: enableShapes,
      editMode: enableShapes,
      dragMode: false,
      cutPolygon: enableShapes,
      rotateMode: enableShapes
    })

    this.map.pm.enableDraw("Marker")

    this.addClearMapControl()
    this.addCustomDragModeControl(enableShapes)
    this.setupNewFeatureListeners()

    if (this.featuresLimit > 1) {
      this.showFeatureLimitHint(this.featuresLimit)
    }
  }

  setupEditingControls(options) {
    this.enableEditing(options)
  }

  addClearMapControl() {
    this.map.pm.Toolbar.createCustomControl({
      name: "clearMap",
      className: "control-icon leaflet-pm-icon-delete",
      title: "Karte zurücksetzen",
      block: "edit",
      onClick: () => {
        this.clearEditableFeatures()
        if (this.callbacks.onClear) this.callbacks.onClear()
      }
    })
  }

  addCustomDragModeControl(enableShapes) {
    if (!enableShapes && !this.adminEditor) return

    this.map.pm.Toolbar.createCustomControl({
      name: "customDragMode",
      className: "control-icon leaflet-pm-icon-custom-drag",
      block: "edit",
      title: "Auswahl modus",
      disableGlobalEditMode: true
    })

    // Rearrange controls
    const editToolbar = this.container.querySelector(".leaflet-pm-toolbar.leaflet-pm-edit")
    if (!editToolbar) return

    const customDragButton = editToolbar.querySelector(".leaflet-pm-icon-custom-drag")?.closest(".button-container")
    if (customDragButton) {
      editToolbar.insertBefore(customDragButton, editToolbar.firstChild)
    }
  }

  addSetCenterControl() {
    const L = window.L
    const map = this.map
    const instance = this

    // Render initial center marker at current map center
    const initialCenter = map.getCenter()
    instance.setCenterMarker = L.marker([initialCenter.lat, initialCenter.lng], {
      icon: instance.createMarkerIcon(getBrandColor())
    }).addTo(map)

    const SetCenterControl = L.Control.extend({
      options: { position: "topright" },

      onAdd(map) {
        const container = L.DomUtil.create("div", "leaflet-bar leaflet-control leaflet-set-center-control")
        const button = L.DomUtil.create("a", "leaflet-control-set-center", container)
        button.innerHTML = '<span class="material-symbols-outlined">my_location</span>'
        button.href = "#"
        button.title = "Kartenmitte per Klick setzen"
        button.role = "button"

        instance.setCenterMode = false

        L.DomEvent.disableClickPropagation(container)
        L.DomEvent.on(button, "click", L.DomEvent.preventDefault)
        L.DomEvent.on(button, "click", () => {
          instance.setCenterMode = !instance.setCenterMode

          if (instance.setCenterMode) {
            button.classList.add("active")
            map.getContainer().style.cursor = "crosshair"
            // Disable drawing mode to prevent marker creation
            map.pm.disableDraw()
          } else {
            button.classList.remove("active")
            map.getContainer().style.cursor = ""
          }
        })

        map.on("click", (e) => {
          if (!instance.setCenterMode) return

          const { lat, lng } = e.latlng

          // Update or create marker
          if (instance.setCenterMarker) {
            instance.setCenterMarker.setLatLng([lat, lng])
          } else {
            instance.setCenterMarker = L.marker([lat, lng], {
              icon: instance.createMarkerIcon(getBrandColor())
            }).addTo(map)
          }

          // Pan map to new center with animation
          map.panTo([lat, lng], { animate: true, duration: 0.5 })

          // Update form inputs via callback (triggered by panTo's move event)

          // Exit set center mode
          instance.setCenterMode = false
          button.classList.remove("active")
          map.getContainer().style.cursor = ""
        })

        return container
      }
    })

    const control = new SetCenterControl()
    control.addTo(this.map)

    // Move the set center control right after the expand control
    const expandControl = this.container.querySelector(".leaflet-control-expand")?.parentElement
    const setCenterControl = this.container.querySelector(".leaflet-set-center-control")
    if (expandControl && setCenterControl) {
      expandControl.after(setCenterControl)
    }
  }

  setupEditableFeatureListeners(layer) {
    const L = window.L

    layer.on("click", () => {
      if (!this.map.pm.globalDrawModeEnabled() &&
          !this.map.pm.globalDragModeEnabled() &&
          !layer.pm.enabled()) {
        layer.pm.enable({ allowSelfIntersection: false })
      }
    })

    this.map.on("click", (e) => {
      const isMarker = layer instanceof L.Marker
      if (!isMarker && layer.pm.enabled() && !layer.getBounds().contains(e.latlng)) {
        layer.pm.disable()
      }
    })

    layer.on("pm:drawstart", () => layer.pm.disable())
    layer.on("pm:dragenable", () => layer.pm.disable())
  }

  setupNewFeatureListeners() {
    const instance = this

    this.map.on("pm:create", (e) => {
      if (e.shape === "Circle") {
        e.layer.options.shape = "Circle"
      }

      e.layer.options.feature_color = instance.featureColor || instance.defaultFeatureColor
      e.layer.options.feature_icon_name = instance.featureIconName
      e.layer.options.feature_category_name = instance.featureCategoryName

      // Enforce feature limit
      if (!instance.adminEditor && instance.editableLayers.length >= instance.featuresLimit) {
        instance.map.removeLayer(instance.editableLayers.pop())
      }

      instance.setupEditableFeatureListeners(e.layer)
      instance.editableLayers.push(e.layer)

      if (instance.callbacks.onCreate) instance.callbacks.onCreate(e)
    })
  }

  onFeatureCreated(event) {
    // Handled in setupNewFeatureListeners
  }

  configureGeoman() {
    this.map.pm.setLang("de")
    this.map.pm.setGlobalOptions({
      markerStyle: {
        icon: this.createMarkerIcon(this.defaultFeatureColor)
      },
      pathOptions: {
        weight: 2,
        color: this.defaultFeatureColor,
        opacity: 1,
        fillColor: this.defaultFeatureColor,
        fillOpacity: 0.2
      },
      templineStyle: { color: this.defaultFeatureColor, dashArray: "5, 10" },
      hintlineStyle: { color: this.defaultFeatureColor, dashArray: "5, 10" }
    })
  }

  // ===========================================================================
  // 7. FORM INPUT SYNCHRONIZATION
  // ===========================================================================

  onMapChange(callbacks) {
    this.callbacks = { ...this.callbacks, ...callbacks }

    this.map.on("move", () => {
      if (callbacks.onMove) {
        callbacks.onMove(this.getCenter(), this.getZoom())
      }
    })

    this.map.on("zoomend", () => {
      if (callbacks.onZoom) {
        callbacks.onZoom(this.getZoom())
      }
    })

    this.map.on("pm:dragend", () => {
      if (callbacks.onMove) {
        callbacks.onMove(this.getCenter(), this.getZoom())
      }
    })
  }

  getEditableFeatures() {
    const L = window.L

    // Extend L.Layer to include custom properties in GeoJSON
    L.Layer.include({
      toGeoJSONWithOptions() {
        const allowedOptions = ["feature_color", "feature_icon_name", "feature_category_name"]
        const geojson = this.toGeoJSON()
        geojson.properties = geojson.properties || {}

        allowedOptions.forEach(option => {
          if (option in this.options) {
            geojson.properties[option] = this.options[option]
          }
        })

        return geojson
      }
    })

    const featuresData = this.editableLayers.map(layer => {
      if (layer.options.shape === "Circle") {
        return L.PM.Utils.circleToPolygon(layer, 60).toGeoJSONWithOptions()
      }
      return layer.toGeoJSONWithOptions()
    })

    return {
      type: "FeatureCollection",
      features: featuresData
    }
  }

  clearEditableFeatures() {
    this.editableLayers.forEach(layer => this.map.removeLayer(layer))
    this.editableLayers = []
  }

  // ===========================================================================
  // 8. MAP STATE GETTERS/SETTERS
  // ===========================================================================

  getCenter() {
    const center = this.map.getCenter()
    return { lat: center.lat, lng: center.lng }
  }

  getZoom() {
    return this.map.getZoom()
  }

  getAltitude() {
    return 0
  }

  setView(lat, lng, zoom) {
    this.map.setView([lat, lng], zoom)
  }

  // ===========================================================================
  // 9. UI/UX HELPERS
  // ===========================================================================

  showFeatureLimitHint(limit) {
    const L = window.L

    const hintControl = L.control({ position: "bottomleft" })
    hintControl.onAdd = () => {
      const container = L.DomUtil.create("div", "feature-limit-hint leaflet-control-attribution")
      container.innerHTML = `Sie dürfen insgesamt ${limit} Pins setzen.`
      container.style.color = "#ff0000"
      return container
    }
    hintControl.addTo(this.map)
  }

  getDefaultFeatureColor(isAdmin = false) {
    if (isAdmin) return "#ff0000"
    return getBrandColor()
  }

  invalidateSize() {
    this.map.invalidateSize()
  }

  /**
   * Set feature styling for next created features
   */
  setFeatureStyle(color, iconName, categoryName) {
    this.featureColor = color
    this.featureIconName = iconName
    this.featureCategoryName = categoryName

    // Update Geoman global options
    this.map.pm.setGlobalOptions({
      markerStyle: {
        icon: this.createMarkerIcon(color || this.defaultFeatureColor, iconName)
      },
      pathOptions: {
        color: color || this.defaultFeatureColor,
        fillColor: color || this.defaultFeatureColor
      }
    })
  }
}

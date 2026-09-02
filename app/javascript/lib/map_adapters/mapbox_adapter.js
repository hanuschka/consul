import BaseAdapter from "./base_adapter"
import { getBrandColor, hexToRgba, MapPopup, numberOrDefault } from "./map_utils"

/**
 * Mapbox GL JS Adapter
 *
 * Implements the BaseAdapter interface for Mapbox GL maps.
 * Scripts are loaded asynchronously on first use.
 */
export default class MapboxAdapter extends BaseAdapter {
  static scriptsLoaded = false
  static scriptsLoading = false
  static loadQueue = []

  // ===========================================================================
  // 1. INITIALIZATION & CONFIGURATION
  // ===========================================================================

  initialize(container, options) {
    this.container = container
    this.options = options
    this.adminEditor = options.adminEditor || false
    this.defaultFeatureColor = this.getDefaultFeatureColor(this.adminEditor)
    this.featuresLimit = options.featuresLimit || 1
    this.draw = null
    this.layerControl = null
    this.instructionOverlay = null

    // Feature styling state
    this.featureColor = null
    this.featureIconName = null
    this.featureIconUnicode = null
    this.featureCategoryName = null

    return this.loadScripts().then(() => {
      this.createMap(container, options)
      this.addInstructionOverlay()
      this.setupExpandControl()
      this.addResetViewControl()
      this.setupPlugins()
      this.setupFormSyncListeners()
      this.observeContainerResize()
    })
  }

  destroy() {
    this.stopObservingContainerResize()

    if (this._geojsonLegends) {
      this._geojsonLegends.forEach(legend => legend.remove())
      this._geojsonLegends = []
    }
    if (this.map) {
      this.map.remove()
      this.map = null
    }
    this.editableLayers = []
    this.baseLayers = {}
    this.overlayLayers = {}
    this.draw = null
  }

  /**
   * Load Mapbox GL and all plugins asynchronously
   */
  loadScripts() {
    return new Promise((resolve) => {
      if (MapboxAdapter.scriptsLoaded) {
        resolve()
        return
      }

      MapboxAdapter.loadQueue.push(resolve)

      if (MapboxAdapter.scriptsLoading) return

      MapboxAdapter.scriptsLoading = true

      const cssUrls = [
        "https://api.mapbox.com/mapbox-gl-js/v3.12.0/mapbox-gl.css",
        "https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-draw/v1.5.0/mapbox-gl-draw.css",
        "https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-geocoder/v5.0.3/mapbox-gl-geocoder.css"
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
        "https://api.mapbox.com/mapbox-gl-js/v3.12.0/mapbox-gl.js",
        "https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-draw/v1.5.0/mapbox-gl-draw.js",
        "https://api.mapbox.com/mapbox-gl-js/plugins/mapbox-gl-geocoder/v5.0.3/mapbox-gl-geocoder.min.js"
      ]

      const loadNext = (index) => {
        if (index >= jsUrls.length) {
          MapboxAdapter.scriptsLoaded = true
          MapboxAdapter.loadQueue.forEach(cb => cb())
          MapboxAdapter.loadQueue = []
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
    const mapboxgl = window.mapboxgl

    mapboxgl.accessToken = options.mapboxPublicToken

    this.initialCenter = [options.longitude, options.latitude]
    this.initialZoom = options.zoom
    this.initialPitch = 10

    this.map = new mapboxgl.Map({
      container: container,
      center: [options.longitude, options.latitude],
      zoom: options.zoom,
      pitch: this.initialPitch,
      preserveDrawingBuffer: true,
      style: options.mapboxStyleId || "mapbox://styles/mapbox/streets-v12",
      cooperativeGestures: true,
      locale: {
        "ScrollZoomBlocker.CtrlMessage": "Zum Zoomen der Karte Strg + Scrollen verwenden",
        "ScrollZoomBlocker.CmdMessage": "⌘ gedrückt halten und scrollen, um die Karte zu zoomen",
        "TouchPanBlocker.Message": "Zum Verschieben der Karte zwei Finger verwenden"
      }
    })

    // Set up load handler for deferred operations
    this.mapLoaded = new Promise(resolve => {
      this.map.on("load", resolve)
    })
  }

  setupExpandControl() {
    const instance = this

    class ExpandControl {
      onAdd(map) {
        this._map = map
        this._container = document.createElement("div")
        this._container.className = "mapboxgl-ctrl mapboxgl-ctrl-group"

        const button = document.createElement("button")
        button.type = "button"
        button.className = "mapbox-expand-control-button"
        button.innerHTML = '<span class="material-symbols-outlined">fullscreen</span>'
        button.title = "Vollbild-Modus"

        this._container.appendChild(button)

        button.addEventListener("click", () => {
          if (instance.container.classList.contains("expanded")) {
            instance.container.classList.remove("expanded")
            button.innerHTML = '<span class="material-symbols-outlined">fullscreen</span>'
          } else {
            instance.container.classList.add("expanded")
            button.innerHTML = '<span class="material-symbols-outlined">fullscreen_exit</span>'
          }
          map.resize()
          instance.toggleControlVisibility()
        })

        return this._container
      }

      onRemove() {
        this._container.parentNode.removeChild(this._container)
        this._map = undefined
      }
    }

    this.map.addControl(new ExpandControl(), "top-right")
  }

  addResetViewControl() {
    const instance = this

    class ResetViewControl {
      onAdd(map) {
        this._container = document.createElement("div")
        this._container.className = "mapboxgl-ctrl mapboxgl-ctrl-group"

        const button = document.createElement("button")
        button.type = "button"
        button.innerHTML = '<span class="material-symbols-outlined">home</span>'
        button.title = "Ansicht zurücksetzen"

        button.addEventListener("click", () => {
          map.flyTo({
            center: instance.initialCenter,
            zoom: instance.initialZoom,
            pitch: instance.initialPitch,
            bearing: 0
          })
        })

        this._container.appendChild(button)
        return this._container
      }

      onRemove() {
        this._container.parentNode.removeChild(this._container)
      }
    }

    this.map.addControl(new ResetViewControl(), "top-right")
  }

  toggleControlVisibility() {
    const controls = [
      this.container.querySelector(".mapboxgl-ctrl-top-left"),
      this.container.querySelector(".mapbox-layer-control"),
      this.instructionOverlay
    ]

    const isSmall = this.container.offsetWidth < 700
    controls.forEach(control => {
      if (control) control.style.display = isSmall ? "none" : ""
    })
  }

  addInstructionOverlay() {
    const overlay = document.createElement("div")
    overlay.className = "mapbox-instruction-overlay"

    this.container.style.position = "relative"
    this.container.appendChild(overlay)

    this.instructionOverlay = overlay
  }

  // ===========================================================================
  // 3. LAYER MANAGEMENT
  // ===========================================================================

  setupLayers(layers) {
    if (!layers || layers.length === 0) return

    this.mapLoaded.then(() => {
      this.addLayerControl()

      layers.forEach(layerData => {
        this.createLayer(layerData)
        if (this.layerControl) {
          this.addLayerToControl(layerData)
        }
      })
    })
  }

  createLayer(layerData) {
    const sourceId = `ext-layersource-${layerData.id}`
    const layerId = `ext-layer-${layerData.id}`

    if (layerData.protocol === "wms") {
      const baseUrl = layerData.provider
      const separator = baseUrl.includes("?") ? "&" : "?"
      const wmsParams = [
        "service=WMS",
        "request=GetMap",
        `layers=${layerData.layer_names}`,
        "format=image/png",
        "styles=",
        `transparent=${layerData.transparent ? "true" : "false"}`,
        "version=1.1.1",
        "width=256",
        "height=256",
        "srs=EPSG:3857",
        "bbox={bbox-epsg-3857}"
      ]

      const wmsUrl = baseUrl + separator + wmsParams.join("&")

      this.map.addSource(sourceId, {
        type: "raster",
        tiles: [wmsUrl],
        tileSize: 256
      })

      this.map.addLayer({
        id: layerId,
        type: "raster",
        source: sourceId,
        paint: {
          "raster-opacity": parseFloat(layerData.opacity) || 1
        },
        layout: {
          visibility: layerData.show_by_default ? "visible" : "none"
        }
      })

      if (layerData.base) {
        this.baseLayers[layerData.name] = { layerId, sourceId }
      } else {
        this.overlayLayers[layerData.name] = { layerId, sourceId }
      }
    } else if (layerData.protocol === "geojson") {
      if (!layerData.data_url) return

      const cfg = layerData.config || {}
      const lineLayerId = `${layerId}-line`
      const visibility = layerData.show_by_default ? "visible" : "none"

      this.map.addSource(sourceId, {
        type: "geojson",
        data: layerData.data_url
      })

      // Fill layer carries the control's layerId so the checkbox toggles it.
      this.map.addLayer({
        id: layerId,
        type: "fill",
        source: sourceId,
        paint: {
          "fill-color": this.geoJsonFillColor(cfg),
          "fill-opacity": this.geoJsonFillOpacity(cfg)
        },
        layout: { visibility }
      })

      this.map.addLayer({
        id: lineLayerId,
        type: "line",
        source: sourceId,
        paint: {
          "line-color": (cfg.style && cfg.style.color) || "#1A3C8C",
          "line-width": this.geoJsonLineWidth(cfg)
        },
        layout: { visibility }
      })

      // geojson is always an overlay (base is forced false server-side).
      this.overlayLayers[layerData.name] = { layerId, sourceId, lineLayerId }

      if (cfg.choropleth && cfg.choropleth.enabled) {
        this.addChoroplethLegend(cfg)
      }
    }
  }

  geoJsonFillOpacity(cfg) {
    const style = cfg.style || {}
    return numberOrDefault(style.fillOpacity, 0.3)
  }

  geoJsonLineWidth(cfg) {
    return numberOrDefault(cfg.style && cfg.style.weight, 1)
  }

  // Returns a Mapbox GL paint value for fill-color: a flat color, or a
  // data-driven "step" expression when choropleth is enabled.
  geoJsonFillColor(cfg) {
    const style = cfg.style || {}
    const ch = cfg.choropleth || {}
    const flat = style.fillColor || "#3366CC"

    if (!ch.enabled) return flat

    const breaks = (ch.breaks || []).map(b => parseFloat(b))
    const colors = ch.colors || []
    if (!breaks.length || colors.length !== breaks.length + 1) return flat

    const step = ["step", ["to-number", ["get", ch.property]], colors[0]]
    for (let i = 0; i < breaks.length; i++) {
      step.push(breaks[i], colors[i + 1])
    }

    // null / non-numeric values fall back to the no-data color.
    return [
      "case",
      ["==", ["typeof", ["get", ch.property]], "number"],
      step,
      ch.no_data_color || "#cccccc"
    ]
  }

  addChoroplethLegend(cfg) {
    const ch = cfg.choropleth || {}
    const breaks = ch.breaks || []
    const colors = ch.colors || []

    const container = document.createElement("div")
    container.className = "map-choropleth-legend mapbox-choropleth-legend"
    // Inline styles so the legend renders correctly on both admin and frontend
    // bundles without depending on map component SCSS being loaded.
    container.style.cssText = [
      "position:absolute", "bottom:24px", "right:8px", "z-index:1",
      "max-width:220px", "padding:8px 10px", "background:#fff",
      "border-radius:4px", "box-shadow:0 1px 4px rgba(0,0,0,0.3)",
      "font-size:12px", "line-height:1.5"
    ].join(";")

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
    this.container.appendChild(container)

    this._geojsonLegends = this._geojsonLegends || []
    this._geojsonLegends.push(container)
  }

  ensureBaseLayerExists() {
    // Mapbox uses its own style as the base layer
  }

  addLayerControl() {
    const instance = this

    class LayerControl {
      constructor() {
        this.dropdownList = null
      }

      onAdd(map) {
        this._map = map
        this._container = document.createElement("div")
        this._container.className = "mapboxgl-ctrl mapboxgl-ctrl-group mapbox-layer-control"

        const button = document.createElement("button")
        button.type = "button"
        button.className = "mapbox-layer-control-button"
        button.innerHTML = '<span class="material-symbols-outlined">layers</span>'
        button.title = "Kartenebenen"

        const dropdown = document.createElement("div")
        dropdown.className = "mapbox-layer-control-dropdown"
        dropdown.style.display = "none"

        this.dropdownList = document.createElement("div")
        this.dropdownList.className = "mapbox-layer-select-section"

        const title = document.createElement("div")
        title.className = "mapbox-layer-select-section-title"
        title.textContent = "Kartenebenen"
        this.dropdownList.appendChild(title)

        // POI toggle
        const poiLabel = this.createLayerCheckbox("Orte von Interesse", "poi-label", true, "checkbox")
        this.dropdownList.appendChild(poiLabel)

        dropdown.appendChild(this.dropdownList)
        this._container.appendChild(button)
        this._container.appendChild(dropdown)

        button.addEventListener("click", (e) => {
          e.stopPropagation()
          dropdown.style.display = dropdown.style.display === "none" ? "block" : "none"
        })

        document.addEventListener("click", (e) => {
          if (!this._container.contains(e.target)) {
            dropdown.style.display = "none"
          }
        })

        return this._container
      }

      createLayerCheckbox(name, layerId, isChecked, inputType) {
        const label = document.createElement("label")
        label.className = "mapbox-layer-checkbox-label"

        const input = document.createElement("input")
        input.type = inputType
        input.checked = isChecked
        if (inputType === "radio") input.name = "base-layer"

        const span = document.createElement("span")
        span.textContent = name

        label.appendChild(input)
        label.appendChild(span)

        input.addEventListener("change", () => {
          instance.toggleLayer(layerId, input.checked)
        })

        return label
      }

      onRemove() {
        this._container.parentNode.removeChild(this._container)
        this._map = undefined
      }
    }

    this.layerControl = new LayerControl()
    this.map.addControl(this.layerControl, "top-right")
  }

  addLayerToControl(layerData) {
    if (!this.layerControl) return

    const isVisible = layerData.show_by_default
    const label = this.layerControl.createLayerCheckbox(
      layerData.name,
      `ext-layer-${layerData.id}`,
      isVisible,
      layerData.base ? "radio" : "checkbox"
    )

    this.layerControl.dropdownList.appendChild(label)
  }

  toggleLayer(layerId, visible) {
    const visibility = visible ? "visible" : "none"
    if (this.map.getLayer(layerId)) {
      this.map.setLayoutProperty(layerId, "visibility", visibility)
    }
    // geojson overlays add a companion outline layer that toggles in lockstep.
    const lineLayerId = `${layerId}-line`
    if (this.map.getLayer(lineLayerId)) {
      this.map.setLayoutProperty(lineLayerId, "visibility", visibility)
    }
  }

  // ===========================================================================
  // 4. PLUGINS & ADDITIONAL CONTROLS
  // ===========================================================================

  setupPlugins() {
    this.addNavigationControl()
    this.addSearchControl()
    this.addLocateControl()
    // Mapbox has built-in clustering, set up in renderFeatures
  }

  addNavigationControl() {
    const mapboxgl = window.mapboxgl
    this.map.addControl(new mapboxgl.NavigationControl(), "top-left")
  }

  addSearchControl() {
    const mapboxgl = window.mapboxgl
    const MapboxGeocoder = window.MapboxGeocoder

    if (MapboxGeocoder) {
      this.map.addControl(new MapboxGeocoder({
        accessToken: mapboxgl.accessToken,
        mapboxgl: mapboxgl,
        countries: "DE",
        marker: false,
        placeholder: "Nach Adresse suchen"
      }), "top-left")

      const searchInput = this.container.querySelector(".mapboxgl-ctrl-geocoder--input")
      if (searchInput) {
        searchInput.setAttribute("title", "Nach Adresse suchen")
        searchInput.setAttribute("aria-label", "Nach Adresse suchen")
      }
    }
  }

  addLocateControl() {
    const mapboxgl = window.mapboxgl
    this.map.addControl(new mapboxgl.GeolocateControl({
      positionOptions: { enableHighAccuracy: true },
      trackUserLocation: true
    }), "top-left")
  }

  setupClustering() {
    // Mapbox clustering is set up per-source in addFeatures
  }

  // ===========================================================================
  // 5. FEATURE RENDERING
  // ===========================================================================

  addFeatures(features, options = {}) {
    if (!features || Object.keys(features).length === 0) return

    const editable = options.editable === true

    if (editable) {
      // Editable features are handled by MapboxDraw
      this.mapLoaded.then(() => {
        if (this.draw) {
          const formatted = this.formatFeatures(features)
          formatted.features.forEach(feature => {
            const added = this.draw.add(feature)
            if (added && added.length > 0) {
              this.editableLayers.push(added[0])
            }
          })
        }
      })
    } else {
      // Read-only features with clustering
      this.mapLoaded.then(() => {
        this.renderReadOnlyFeatures(features)
      })
    }
  }

  renderReadOnlyFeatures(features) {
    const mapboxgl = window.mapboxgl
    const formatted = this.formatFeatures(features)

    // Separate points for clustering
    const pointFeatures = {
      type: "FeatureCollection",
      features: formatted.features.filter(f => f.geometry.type === "Point")
    }

    // Process icon unicode
    pointFeatures.features.forEach(feature => {
      if (feature.properties?.feature_icon_unicode) {
        feature.properties.feature_icon_unicode_processed =
          String.fromCharCode(parseInt(feature.properties.feature_icon_unicode, 16))
      }
    })

    const clusterColor = hexToRgba(this.defaultFeatureColor, 0.75)

    // Points with clustering
    this.map.addSource("user-features-points", {
      type: "geojson",
      data: pointFeatures,
      cluster: true,
      clusterMaxZoom: 17,
      clusterRadius: 50
    })

    // Cluster circles
    this.map.addLayer({
      id: "user-features-circles-clusters",
      type: "circle",
      source: "user-features-points",
      filter: ["has", "point_count"],
      paint: {
        "circle-color": ["step", ["get", "point_count"], clusterColor, 10, clusterColor, 30, clusterColor],
        "circle-radius": ["step", ["get", "point_count"], 18, 10, 22, 28, 25]
      }
    })

    // Cluster count
    this.map.addLayer({
      id: "user-features-circles-cluster-count",
      type: "symbol",
      source: "user-features-points",
      filter: ["has", "point_count"],
      layout: {
        "text-field": "{point_count_abbreviated}",
        "text-font": ["DIN Offc Pro Medium", "Arial Unicode MS Bold"],
        "text-size": 12
      },
      paint: { "text-color": "#ffffff" }
    })

    // Individual points as DOM markers (pin-shaped, matching Leaflet style)
    this.readOnlyMarkers = {}
    this.readOnlyMarkersOnScreen = {}

    const updateMarkers = () => {
      if (!this.map.isSourceLoaded("user-features-points")) return

      const newMarkers = {}
      const sourceFeatures = this.map.querySourceFeatures("user-features-points")

      for (const feature of sourceFeatures) {
        if (feature.properties.cluster) continue

        const coords = feature.geometry.coordinates
        const id = feature.properties.id || feature.id || `${coords[0]}_${coords[1]}`

        let marker = this.readOnlyMarkers[id]
        if (!marker) {
          const color = this.adminEditor ? "#ff0000" :
            feature.properties?.feature_color || feature.properties?.color || this.defaultFeatureColor
          const iconName = feature.properties?.feature_icon_name || "circle"

          const el = document.createElement("div")
          el.className = "map-marker"
          el.innerHTML = `<div class="map-icon icon-${iconName}" style="background-color: ${color}"></div>`

          marker = new mapboxgl.Marker({ element: el, anchor: "bottom" })
            .setLngLat(coords)
          this.readOnlyMarkers[id] = marker
        }

        newMarkers[id] = marker
        if (!this.readOnlyMarkersOnScreen[id]) marker.addTo(this.map)
      }

      for (const id in this.readOnlyMarkersOnScreen) {
        if (!newMarkers[id]) this.readOnlyMarkersOnScreen[id].remove()
      }
      this.readOnlyMarkersOnScreen = newMarkers
    }

    this.map.on("render", updateMarkers)

    const featureColor = this.adminEditor ? "#ff0000" :
      ["coalesce", ["get", "feature_color"], ["get", "color"], this.defaultFeatureColor]

    // Shapes source
    this.map.addSource("user-features-shapes", {
      type: "geojson",
      data: formatted
    })

    // Lines
    this.map.addLayer({
      id: "user-features-lines",
      type: "line",
      source: "user-features-shapes",
      filter: ["==", "$type", "LineString"],
      layout: { "line-join": "round", "line-cap": "round" },
      paint: {
        "line-color": featureColor,
        "line-width": 4
      }
    })

    // Polygons
    this.map.addLayer({
      id: "user-features-polygons",
      type: "fill",
      source: "user-features-shapes",
      filter: ["==", "$type", "Polygon"],
      paint: {
        "fill-color": featureColor,
        "fill-opacity": 0.5
      }
    })

    // Cluster click handler
    this.map.on("click", "user-features-circles-clusters", (e) => {
      const features = this.map.queryRenderedFeatures(e.point, {
        layers: ["user-features-circles-clusters"]
      })
      const clusterId = features[0].properties.cluster_id
      this.map.getSource("user-features-points").getClusterExpansionZoom(clusterId, (err, zoom) => {
        if (err) return
        this.map.easeTo({
          center: features[0].geometry.coordinates,
          zoom: zoom + 1
        })
      })
    })

    // Feature popup handlers for shapes (point popups handled by DOM marker click)
    const featureLayers = ["user-features-lines", "user-features-polygons"]
    featureLayers.forEach(layerId => {
      this.map.on("mouseenter", layerId, () => {
        this.map.getCanvas().style.cursor = "pointer"
      })
      this.map.on("mouseleave", layerId, () => {
        this.map.getCanvas().style.cursor = ""
      })
      this.map.on("click", layerId, (e) => this.openFeaturePopup(e))
    })
  }

  addAdminFeatures(features) {
    if (!features || Object.keys(features).length === 0) return

    this.mapLoaded.then(() => {
      const mapboxgl = window.mapboxgl

      if (!this.map.getSource("admin-features")) {
        const formatted = this.formatFeatures(features)

        // Admin point markers as DOM elements (red pins)
        formatted.features
          .filter(f => f.geometry.type === "Point")
          .forEach(feature => {
            const [lng, lat] = feature.geometry.coordinates
            const el = document.createElement("div")
            el.className = "map-marker"
            el.innerHTML = '<div class="map-icon icon-circle" style="background-color: #ff0000"></div>'

            new mapboxgl.Marker({ element: el, anchor: "bottom" })
              .setLngLat([lng, lat])
              .addTo(this.map)
          })

        this.map.addSource("admin-features", {
          type: "geojson",
          data: features
        })

        this.map.addLayer({
          id: "admin-features-lines",
          type: "line",
          source: "admin-features",
          filter: ["==", "$type", "LineString"],
          layout: { "line-join": "round", "line-cap": "round" },
          paint: { "line-color": "#ff0000", "line-width": 4 }
        })

        this.map.addLayer({
          id: "admin-features-polygons",
          type: "fill",
          source: "admin-features",
          filter: ["==", "$type", "Polygon"],
          paint: { "fill-color": "#ff0000", "fill-opacity": 0.2 }
        })
      }

      // Add to layer control
      if (this.layerControl) {
        const label = document.createElement("label")
        label.className = "mapbox-layer-checkbox-label"

        const input = document.createElement("input")
        input.type = "checkbox"
        input.checked = true

        const span = document.createElement("span")
        span.textContent = "Verwaltungseinträge"

        label.appendChild(input)
        label.appendChild(span)

        input.addEventListener("change", () => {
          this.toggleLayer("admin-features-lines", input.checked)
          this.toggleLayer("admin-features-polygons", input.checked)
        })

        this.layerControl.dropdownList.appendChild(label)
      }

      // Popup for admin features
      const popupContent = '<div class="map-popup-status-message">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>'
      const adminLayers = ["admin-features-lines", "admin-features-polygons"]
      adminLayers.forEach(layerId => {
        this.map.on("click", layerId, (e) => {
          new mapboxgl.Popup()
            .setLngLat(e.lngLat)
            .setHTML(popupContent)
            .addTo(this.map)
        })
      })

      this.renderAdminFeaturesNote()
    })
  }

  renderAdminFeaturesNote() {
    if (this.instructionOverlay) {
      this.instructionOverlay.insertAdjacentHTML(
        "beforeend",
        '<div class="adminShapeInfo" style="color:#ff0000;">Alle markierten Flächen und Pins in rot sind vom System vorgegeben</div>'
      )
    }
  }

  createMarker(latlng, options = {}) {
    const mapboxgl = window.mapboxgl
    const color = options.color || this.defaultFeatureColor

    return new mapboxgl.Marker({ color })
      .setLngLat([latlng.lng, latlng.lat])
      .addTo(this.map)
  }

  openFeaturePopup(e) {
    if (this._popupOpen) return
    this._popupOpen = true

    const mapboxgl = window.mapboxgl

    if (!e.features || !e.features.length) {
      this._popupOpen = false
      return
    }

    const properties = e.features[0].properties
    const resourceType = properties.resource_type

    const popup = new mapboxgl.Popup({
      offset: 20,
      closeButton: true,
      maxWidth: "250px"
    })
      .setLngLat(e.lngLat)
      .setHTML('<div class="map-popup-status-message">Laden...</div>')
      .addTo(this.map)

    const popupDataUrl = MapPopup.getPopupDataUrl(resourceType, properties)

    if (popupDataUrl) {
      fetch(popupDataUrl)
        .then(response => response.json())
        .then(data => {
          popup.setHTML(MapPopup.generatePopupContent(data, resourceType, properties))
        })
        .catch(() => {
          popup.setHTML('<div class="map-popup-status-message error">Failed to load data</div>')
        })
        .finally(() => {
          this._popupOpen = false
        })
    } else {
      this._popupOpen = false
    }
  }

  // ===========================================================================
  // 6. EDITING CONTROLS
  // ===========================================================================

  enableEditing(options = {}) {
    const enableShapes = options.enableShapes !== false

    this.mapLoaded.then(() => {
      this.setupEditingControls({ enableShapes })
    })
  }

  setupEditingControls(options) {
    const MapboxDraw = window.MapboxDraw
    if (!MapboxDraw) return

    const enableShapes = options.enableShapes !== false

    this.draw = new MapboxDraw({
      displayControlsDefault: false,
      controls: {
        point: true,
        line_string: enableShapes,
        polygon: enableShapes,
        trash: enableShapes
      },
      defaultMode: "draw_point",
      userProperties: true,
      styles: this.getDrawStyles()
    })

    this.map.addControl(this.draw, "top-right")

    this.addSwitchToSimpleSelectControl()
    this.setupNewFeatureListeners()
    this.rearrangeEditingControls()

    if (this.featuresLimit > 1) {
      this.showFeatureLimitHint(this.featuresLimit)
    }
  }

  addSwitchToSimpleSelectControl() {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "mapbox-switch-to-simple-select-control-button"
    button.innerHTML = '<span class="material-symbols-outlined">pan_tool</span>'
    button.title = "Auswahlmodus"

    const pointBtn = this.container.querySelector(".mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_point")
    if (pointBtn) {
      pointBtn.insertAdjacentElement("afterend", button)
    }

    button.addEventListener("click", () => {
      if (button.classList.contains("active")) {
        button.classList.remove("active")
        this.draw.changeMode("draw_point")
      } else {
        button.classList.add("active")
        this.container.querySelectorAll(".mapbox-gl-draw_ctrl-draw-btn").forEach(btn => {
          btn.classList.remove("active")
        })
        this.draw.changeMode("simple_select")
      }
    })

    this.map.on("draw.modechange", () => {
      button.classList.remove("active")
    })
  }

  addClearMapControl() {
    // Mapbox Draw has built-in trash control
  }

  addSetCenterControl() {
    const mapboxgl = window.mapboxgl
    const instance = this

    // Render initial center marker at current map center
    this.mapLoaded.then(() => {
      const center = this.map.getCenter()
      const markerData = {
        type: "FeatureCollection",
        features: [{
          type: "Feature",
          geometry: { type: "Point", coordinates: [center.lng, center.lat] }
        }]
      }

      this.map.addSource("set-center-marker", { type: "geojson", data: markerData })
      this.map.addLayer({
        id: "set-center-marker-circle",
        type: "circle",
        source: "set-center-marker",
        paint: {
          "circle-radius": 16,
          "circle-color": getBrandColor(),
          "circle-opacity": 0.75
        }
      })
    })

    class SetCenterControl {
      onAdd(map) {
        this._map = map
        this._container = document.createElement("div")
        this._container.className = "mapboxgl-ctrl mapboxgl-ctrl-group"

        const button = document.createElement("button")
        button.type = "button"
        button.className = "mapbox-set-center-control-button"
        button.innerHTML = '<span class="material-symbols-outlined">my_location</span>'
        button.title = "Kartenmitte per Klick setzen"

        this._container.appendChild(button)

        instance.setCenterMode = false

        button.addEventListener("click", () => {
          instance.setCenterMode = !instance.setCenterMode

          if (instance.setCenterMode) {
            button.classList.add("active")
            map.getCanvas().style.cursor = "crosshair"
            // Disable drawing mode to prevent marker creation
            if (instance.draw) {
              instance.draw.changeMode("simple_select")
            }
          } else {
            button.classList.remove("active")
            map.getCanvas().style.cursor = ""
          }
        })

        map.on("click", (e) => {
          if (!instance.setCenterMode) return

          const { lat, lng } = e.lngLat

          // Update or create marker using source/layer
          const markerData = {
            type: "FeatureCollection",
            features: [{
              type: "Feature",
              geometry: { type: "Point", coordinates: [lng, lat] }
            }]
          }

          if (map.getSource("set-center-marker")) {
            map.getSource("set-center-marker").setData(markerData)
          } else {
            map.addSource("set-center-marker", { type: "geojson", data: markerData })
            map.addLayer({
              id: "set-center-marker-circle",
              type: "circle",
              source: "set-center-marker",
              paint: {
                "circle-radius": 16,
                "circle-color": getBrandColor(),
                "circle-opacity": 0.75
              }
            })
          }

          // Pan map to new center with animation
          map.easeTo({ center: [lng, lat], duration: 500 })

          // Update form inputs via callback (triggered by move event)

          // Exit set center mode
          instance.setCenterMode = false
          button.classList.remove("active")
          map.getCanvas().style.cursor = ""
        })

        return this._container
      }

      onRemove() {
        this._container.parentNode.removeChild(this._container)
        this._map = undefined
      }
    }

    this.map.addControl(new SetCenterControl(), "top-right")
  }

  rearrangeEditingControls() {
    const pointControl = this.container.querySelector(".mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_point")
    const lineControl = this.container.querySelector(".mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_line")
    const polygonControl = this.container.querySelector(".mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_polygon")

    if (!pointControl) return

    const drawingControlsGroup = pointControl.parentElement

    if (lineControl && polygonControl) {
      drawingControlsGroup.insertBefore(pointControl, drawingControlsGroup.firstChild)
      drawingControlsGroup.insertBefore(lineControl, pointControl.nextSibling)
    }

    const simpleSelectControl = this.container.querySelector(".mapbox-switch-to-simple-select-control-button")
    const trashControl = this.container.querySelector(".mapbox-gl-draw_ctrl-draw-btn.mapbox-gl-draw_trash")

    if (simpleSelectControl || trashControl) {
      const editControlsGroup = document.createElement("div")
      editControlsGroup.className = "mapboxgl-ctrl mapboxgl-ctrl-group mapbox-edit-controls-group"
      drawingControlsGroup.insertAdjacentElement("afterend", editControlsGroup)

      if (simpleSelectControl) editControlsGroup.appendChild(simpleSelectControl)
      if (trashControl) editControlsGroup.appendChild(trashControl)
    }
  }

  setupEditableFeatureListeners(layer) {
    // Handled by MapboxDraw internally
  }

  setupNewFeatureListeners() {
    const instance = this

    this.map.on("draw.create", (e) => {
      const currentMode = instance.draw.getMode()
      const newFeature = e.features[0]

      if (instance.featureColor) {
        instance.draw.setFeatureProperty(newFeature.id, "feature_color", instance.featureColor)
      }
      if (instance.featureIconName) {
        instance.draw.setFeatureProperty(newFeature.id, "feature_icon_name", instance.featureIconName)
      }
      if (instance.featureIconUnicode) {
        instance.draw.setFeatureProperty(newFeature.id, "feature_icon_unicode",
          String.fromCharCode(parseInt(instance.featureIconUnicode, 16)))
      }
      if (instance.featureCategoryName) {
        instance.draw.setFeatureProperty(newFeature.id, "feature_category_name", instance.featureCategoryName)
      }

      // Enforce feature limit
      if (!instance.adminEditor && instance.editableLayers.length >= instance.featuresLimit) {
        instance.draw.delete(instance.editableLayers.pop())
      }

      setTimeout(() => instance.draw.changeMode(currentMode), 0)

      instance.editableLayers.push(newFeature.id)

      if (instance.callbacks.onCreate) instance.callbacks.onCreate(e)
    })

    this.map.on("draw.update", (e) => {
      if (instance.callbacks.onEdit) instance.callbacks.onEdit(e)
    })

    this.map.on("draw.delete", (e) => {
      e.features.forEach(feature => {
        instance.editableLayers = instance.editableLayers.filter(id => id !== feature.id)
      })
      if (instance.callbacks.onClear) instance.callbacks.onClear()
    })
  }

  onFeatureCreated(event) {
    // Handled in setupNewFeatureListeners
  }

  getDrawStyles() {
    const featureColor = this.adminEditor ? "#ff0000" :
      ["coalesce", ["get", "user_feature_color"], ["get", "feature_color"], ["get", "color"], this.defaultFeatureColor]

    return [
      {
        id: "gl-draw-polygon-fill",
        type: "fill",
        filter: ["all", ["==", "$type", "Polygon"]],
        paint: {
          "fill-color": featureColor,
          "fill-opacity": ["case", ["==", ["get", "active"], "true"], 0.35, 0.15]
        }
      },
      {
        id: "gl-draw-lines",
        type: "line",
        filter: ["any", ["==", "$type", "LineString"], ["==", "$type", "Polygon"]],
        layout: { "line-cap": "round", "line-join": "round" },
        paint: {
          "line-color": featureColor,
          "line-dasharray": ["case", ["==", ["get", "active"], "true"], ["literal", [5, 5]], ["literal", [5, 0]]],
          "line-width": 2
        }
      },
      {
        id: "gl-draw-point-inner",
        type: "circle",
        filter: ["all", ["==", "$type", "Point"], ["==", "meta", "feature"]],
        paint: {
          "circle-radius": 12,
          "circle-color": featureColor
        }
      },
      {
        id: "gl-draw-point-icon",
        type: "symbol",
        filter: ["all", ["==", "$type", "Point"], ["==", "meta", "feature"], ["has", "user_feature_icon_unicode"]],
        layout: {
          "text-field": ["get", "user_feature_icon_unicode"],
          "text-font": ["Font Awesome 5 Free Regular", "Font Awesome 5 Free Solid", "Font Awesome 5 Brands Regular"],
          "text-size": 10,
          "text-offset": [0, 0.2]
        },
        paint: { "text-color": "#ffffff" }
      },
      {
        id: "gl-draw-vertex-outer",
        type: "circle",
        filter: ["all", ["==", "$type", "Point"], ["==", "meta", "vertex"], ["!=", "mode", "simple_select"]],
        paint: {
          "circle-radius": ["case", ["==", ["get", "active"], "true"], 8, 9],
          "circle-color": this.adminEditor ? "#ff0000" :
            ["case", ["has", "user_feature_color"], ["get", "user_feature_color"], this.defaultFeatureColor]
        }
      },
      {
        id: "gl-draw-vertex-inner",
        type: "circle",
        filter: ["all", ["==", "$type", "Point"], ["==", "meta", "vertex"], ["!=", "mode", "simple_select"]],
        paint: {
          "circle-radius": ["case", ["==", ["get", "active"], "true"], 5, 7],
          "circle-color": "#fff"
        }
      }
    ]
  }

  // ===========================================================================
  // 7. FORM INPUT SYNCHRONIZATION
  // ===========================================================================

  setupFormSyncListeners() {
    // Will be connected via onMapChange
  }

  onMapChange(callbacks) {
    this.callbacks = { ...this.callbacks, ...callbacks }

    this.map.on("moveend", () => {
      if (callbacks.onMove) {
        callbacks.onMove(this.getCenter(), this.getZoom())
      }
    })

    this.map.on("zoomend", () => {
      if (callbacks.onZoom) {
        callbacks.onZoom(this.getZoom())
      }
    })

    this.map.on("dragend", () => {
      if (callbacks.onMove) {
        callbacks.onMove(this.getCenter(), this.getZoom())
      }
    })
  }

  getEditableFeatures() {
    if (!this.draw) {
      return { type: "FeatureCollection", features: [] }
    }

    const allFeatures = this.draw.getAll()
    const editableFeatures = allFeatures.features.filter(feature =>
      this.editableLayers.includes(feature.id)
    )

    return {
      type: "FeatureCollection",
      features: editableFeatures
    }
  }

  clearEditableFeatures() {
    if (this.draw) {
      this.editableLayers.forEach(id => this.draw.delete(id))
      this.editableLayers = []
    }
    if (this.callbacks.onClear) this.callbacks.onClear()
  }

  // ===========================================================================
  // 8. MAP STATE GETTERS/SETTERS
  // ===========================================================================

  getCenter() {
    if (!this.map) return { lat: this.options.latitude, lng: this.options.longitude }
    const center = this.map.getCenter()
    return { lat: center.lat, lng: center.lng }
  }

  getZoom() {
    if (!this.map) return this.options.zoom
    return this.map.getZoom()
  }

  getAltitude() {
    if (!this.map) return this.options.altitude || 0
    return this.map.getPitch()
  }

  setView(lat, lng, zoom) {
    if (!this.map) return
    this.map.flyTo({ center: [lng, lat], zoom })
  }

  // ===========================================================================
  // 9. UI/UX HELPERS
  // ===========================================================================

  showFeatureLimitHint(limit) {
    if (this.instructionOverlay) {
      this.instructionOverlay.insertAdjacentHTML(
        "beforeend",
        `<div class="feature-limit-hint" style="color:#ff0000;">Sie dürfen insgesamt ${limit} Pins setzen.</div>`
      )
    }
  }

  getDefaultFeatureColor(isAdmin = false) {
    if (isAdmin) return "#ff0000"
    return getBrandColor()
  }

  invalidateSize() {
    if (this.map) this.map.resize()
  }

  /**
   * Set feature styling for next created features
   */
  setFeatureStyle(color, iconName, iconUnicode, categoryName) {
    this.featureColor = color
    this.featureIconName = iconName
    this.featureIconUnicode = iconUnicode
    this.featureCategoryName = categoryName
  }

  /**
   * Format features for Mapbox
   */
  formatFeatures(features) {
    // If already a FeatureCollection, return as-is
    if (features.type === "FeatureCollection") {
      return features
    }

    // Wrap in FeatureCollection if needed
    return {
      type: "FeatureCollection",
      features: Array.isArray(features) ? features : [features]
    }
  }
}

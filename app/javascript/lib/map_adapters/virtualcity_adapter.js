import BaseAdapter from "./base_adapter"
import { getBrandColor, hexToRgba, MapPopup } from "./map_utils"

/**
 * Virtual City Map Adapter
 *
 * Implements the BaseAdapter interface for VCS (Virtual City Systems) 3D maps.
 * Uses Cesium for 3D globe rendering. Scripts are loaded asynchronously on first use.
 */
export default class VirtualCityAdapter extends BaseAdapter {
  static scriptsLoaded = false
  static scriptsLoading = null

  static ZOOM_DISTANCE_MATRIX = {
    18: 200, 17: 400, 16: 800, 15: 1400, 14: 2400, 13: 4800, 12: 9600
  }

  // ===========================================================================
  // 1. INITIALIZATION & CONFIGURATION
  // ===========================================================================

  initialize(container, options) {
    this.container = container
    this.options = options
    this.vcsApp = null
    this.adminEditor = options.adminEditor || false
    this.defaultFeatureColor = this.getDefaultFeatureColor(this.adminEditor)
    this.featuresLimit = options.featuresLimit || 1
    this.callbacks = {}
    this.editableLayers = []
    this.featureInfoSession = null
    this.mapActivatedHandlers = []

    // Initialize current map state
    this.currentCenter = { lat: options.latitude, lng: options.longitude }
    this.currentZoom = options.zoom

    return this.loadScripts().then(() => {
      this.createMap(container, options)
      this.observeContainerResize()
    })
  }

  destroy() {
    this.stopObservingContainerResize()
    this.featureInfoSession?.stop()
    this.featureInfoSession = null
    this.mapActivatedHandlers = []
    this.editableLayers = []
    this.vcsApp = null
    window.vcsApp = null
  }

  loadScripts() {
    if (VirtualCityAdapter.scriptsLoaded || window.vcs) {
      VirtualCityAdapter.scriptsLoaded = true
      return Promise.resolve()
    }

    if (VirtualCityAdapter.scriptsLoading) {
      return VirtualCityAdapter.scriptsLoading
    }

    VirtualCityAdapter.scriptsLoading = new Promise(resolve => {
      const existingScript = document.getElementById("vcmap-core")

      if (existingScript) {
        this.waitForVcs().then(resolve)
        return
      }

      const script = document.createElement("script")
      script.id = "vcmap-core"
      script.type = "module"
      script.src = "/vcmap/vcmap-core.js"
      script.onload = () => this.waitForVcs().then(resolve)
      script.onerror = () => {
        console.error("Failed to load VCMap core script")
        resolve()
      }
      document.head.appendChild(script)
    }).then(() => {
      VirtualCityAdapter.scriptsLoaded = true
    })

    return VirtualCityAdapter.scriptsLoading
  }

  waitForVcs(timeout = 10000) {
    return new Promise(resolve => {
      const startTime = Date.now()
      const check = () => {
        if (window.vcs || Date.now() - startTime > timeout) {
          if (!window.vcs) console.error("Timeout waiting for VCS library")
          resolve()
        } else {
          setTimeout(check, 100)
        }
      }
      check()
    })
  }

  // ===========================================================================
  // 2. MAP CREATION & CONTROLS
  // ===========================================================================

  createMap(container, options) {
    if (!window.vcs) {
      console.error("VCS library not loaded")
      return
    }

    window.CESIUM_BASE_URL = "/vcmap/assets/cesium/"

    this.vcsApp = new window.vcs.VcsApp()
    this.vcsApp.maps.setTarget(container)
    window.vcsApp = this.vcsApp

    this.setupMapActivationListener()
    this.loadVcsModule()
  }

  setupExpandControl() {
    const container = this.createControlContainer("expand-control")

    const button = document.createElement("button")
    button.type = "button"
    button.innerHTML = '<span class="material-symbols-outlined">fullscreen</span>'
    button.title = "Vollbild-Modus"
    button.addEventListener("click", e => {
      e.preventDefault()
      const isExpanded = this.container.classList.toggle("expanded")
      button.innerHTML = `<span class="material-symbols-outlined">${isExpanded ? "fullscreen_exit" : "fullscreen"}</span>`
      this.invalidateSize()
      this.toggleControlVisibility()
    })

    container.appendChild(button)
    this.container.appendChild(container)
  }

  toggleControlVisibility() {
    // VCS controls are always visible - no responsive hiding needed for 3D maps
  }

  setupMapActivationListener() {
    this.vcsApp.maps.mapActivated.addEventListener(map => {
      if (map.className !== "CesiumMap") return

      requestAnimationFrame(() => {
        const widget = map.getCesiumWidget?.() || map.cesiumWidget
        widget?.resize?.()
        this.setDefaultView(map)
        this.setupControls()
        this.setupFeatureInfoSession()
        this.mapActivatedHandlers.forEach(handler => handler(map))
      })
    })
  }

  setupControls() {
    this.addZoomControls()
    this.addResetViewControl()
    this.setupExpandControl()
  }

  addZoomControls() {
    const container = this.createControlContainer("zoom-controls")

    const zoomIn = document.createElement("button")
    zoomIn.type = "button"
    zoomIn.innerHTML = "+"
    zoomIn.title = "Hineinzoomen"
    zoomIn.addEventListener("click", e => {
      e.preventDefault()
      this.zoom(false)
    })

    const zoomOut = document.createElement("button")
    zoomOut.type = "button"
    zoomOut.innerHTML = "−"
    zoomOut.title = "Herauszoomen"
    zoomOut.addEventListener("click", e => {
      e.preventDefault()
      this.zoom(true)
    })

    container.append(zoomIn, zoomOut)
    this.container.appendChild(container)
  }

  addResetViewControl() {
    const container = this.createControlContainer("reset-view-control")

    const button = document.createElement("button")
    button.type = "button"
    button.innerHTML = '<span class="material-symbols-outlined">home</span>'
    button.title = "Ansicht zurücksetzen"
    button.addEventListener("click", e => {
      e.preventDefault()
      this.withCesiumMap(map => this.setDefaultView(map))
    })

    container.appendChild(button)
    this.container.appendChild(container)
  }

  createControlContainer(className) {
    const container = document.createElement("div")
    container.className = `controls ${className}`
    return container
  }

  zoom(out = false) {
    this.withCesiumMap(map => {
      map.getViewpoint().then(viewpoint => {
        viewpoint.distance = out ? viewpoint.distance * 2 : viewpoint.distance / 2
        viewpoint.animate = true
        viewpoint.duration = 0.5
        viewpoint.cameraPosition = null
        map.gotoViewpoint(viewpoint)
      })
    })
  }

  // ===========================================================================
  // 3. LAYER MANAGEMENT
  // ===========================================================================

  async loadVcsModule() {
    const moduleUrl = this.options.vcMapModuleUrl
    if (!moduleUrl) {
      console.warn("VCS module URL not configured")
      return
    }

    try {
      const response = await fetch(moduleUrl)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const config = await response.json()
      const module = new window.vcs.VcsModule(config)

      await Promise.resolve(this.vcsApp.addModule(module))

      const mapName = config.startingMapName || "CesiumMap"
      if (this.vcsApp.maps.getByKey(mapName)) {
        await this.vcsApp.maps.setActiveMap(mapName)
      }
    } catch (e) {
      console.error("Failed to load VCS module:", e)
    }
  }

  setupLayers(layers) {
    // VCS layers are configured via the config.json module
  }

  createLayer(layerConfig) {
    // VCS layers are configured via the config.json module
  }

  ensureBaseLayerExists() {
    // VCS base layers are defined in the module config
  }

  addLayerControl() {
    // VCS layer control would need custom implementation
  }

  getOrCreateLayer(layerName) {
    let layer = this.vcsApp.layers.getByKey(layerName)
    if (!layer) {
      layer = new window.vcs.VectorLayer({
        name: layerName,
        projection: window.vcs.wgs84Projection.toJSON(),
        zIndex: window.vcs.maxZIndex - 1,
        vectorProperties: { altitudeMode: "relativeToGround" }
      })
      window.vcs.markVolatile(layer)
      layer.activate()
      this.vcsApp.layers.add(layer)
    }
    return layer
  }

  // ===========================================================================
  // 4. PLUGINS & ADDITIONAL CONTROLS
  // ===========================================================================

  setupPlugins() {
    // VCS plugins are configured via the module config
  }

  addLocateControl() {
    // Geolocation not implemented for VCS
  }

  addSearchControl() {
    // Address search not implemented for VCS
  }

  setupClustering() {
    // Clustering not supported in 3D VCS maps
  }

  // ===========================================================================
  // 5. FEATURE RENDERING
  // ===========================================================================

  addFeatures(features, options = {}) {
    if (!features || Object.keys(features).length === 0) return

    const layerName = options.editable ? "_editorLayer" : "_processCoordinatesLayer"
    this.onCesiumMapReady(() => {
      this.drawGeoJSONFeatures(features, layerName, options)
    })
  }

  addAdminFeatures(features) {
    if (!features || Object.keys(features).length === 0) return

    this.onCesiumMapReady(() => {
      this.drawGeoJSONFeatures(features, "_adminShapeLayer", { editable: false, isAdmin: true })
      this.renderAdminFeaturesNote()
    })
  }

  renderAdminFeaturesNote() {
    const note = document.createElement("div")
    note.className = "controls admin-note"
    note.style.cssText = "bottom: 10px; left: 10px; color: #ff0000; font-size: 12px; background: rgba(255,255,255,0.9); padding: 4px 8px; border-radius: 4px;"
    note.textContent = "Alle markierten Flächen und Pins in rot sind vom System vorgegeben"
    this.container.appendChild(note)
  }

  drawGeoJSONFeatures(geojson, layerName, options = {}) {
    if (!this.vcsApp) return

    const layer = this.getOrCreateLayer(layerName)
    const features = geojson.features || [geojson]
    features.forEach(f => this.drawFeature(f, layer, options))
  }

  drawFeature(featureData, layer, options = {}) {
    const { geometry, properties = {} } = featureData
    const color = options.isAdmin ? "#ff0000" : (properties.feature_color || properties.color || this.defaultFeatureColor)

    let feature
    if (geometry.type === "Point") {
      feature = this.createPointFeature(geometry.coordinates, color)
    } else if (geometry.type === "Polygon") {
      feature = this.createPolygonFeature(geometry.coordinates[0], color)
    }

    if (feature) {
      feature.data = properties
      feature.resource_id = properties.id
      layer.addFeatures([feature])
    }
  }

  createPointFeature(coords, color) {
    const feature = new window.ol.Feature({
      geometry: new window.ol.geom.Point([coords[0], coords[1], coords[2] || 0])
    })

    const style = new window.vcs.VectorStyleItem({})
    style.image = new window.ol.style.Icon({ src: this.buildPinSvg(color) })
    feature.setStyle(style.style)
    feature.set("olcs_altitudeMode", "absolute")

    return feature
  }

  createPolygonFeature(coords, color) {
    const feature = new window.ol.Feature({
      geometry: new window.ol.geom.Polygon([coords.map(c => [c[0], c[1], c[2] || 0])])
    })

    const style = new window.vcs.VectorStyleItem({})
    style.fillColor = hexToRgba(color, 0.3)
    style.stroke = new window.ol.style.Stroke({ color, width: 1 })
    feature.setStyle(style.style)
    feature.set("olcs_altitudeMode", "relativeToGround")

    return feature
  }

  createMarker(latlng, options = {}) {
    const color = options.color || this.defaultFeatureColor
    const layer = this.getOrCreateLayer("_markersLayer")
    const feature = this.createPointFeature([latlng.lng, latlng.lat, 0], color)
    layer.addFeatures([feature])
    return feature
  }

  openFeaturePopup(feature) {
    this.showFeatureInfo(feature)
  }

  buildPinSvg(color) {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 384 512">` +
      `<path fill="${hexToRgba(color, 0.8)}" d="M172.3 501.7C27 291 0 269.4 0 192 0 86 86 0 192 0s192 86 192 192c0 77.4-27 99-172.3 309.7-9.5 13.8-29.9 13.8-39.5 0z"/>` +
      `</svg>`
    return "data:image/svg+xml;base64," + btoa(unescape(encodeURIComponent(svg)))
  }

  // ===========================================================================
  // 6. EDITING CONTROLS
  // ===========================================================================

  enableEditing(options = {}) {
    this.onCesiumMapReady(() => {
      this.setupEditingControls(options)
    })
  }

  setupEditingControls(options = {}) {
    const enableShapes = options.enableShapes !== false

    const container = this.createControlContainer("editing-controls")

    const drawPoint = document.createElement("button")
    drawPoint.type = "button"
    drawPoint.innerHTML = '<span class="material-symbols-outlined">location_on</span>'
    drawPoint.title = "Pin setzen"
    drawPoint.addEventListener("click", e => {
      e.preventDefault()
      this.startDrawing(window.vcs.GeometryType.Point)
    })
    container.appendChild(drawPoint)

    if (enableShapes) {
      const drawPolygon = document.createElement("button")
      drawPolygon.type = "button"
      drawPolygon.innerHTML = '<span class="material-symbols-outlined">pentagon</span>'
      drawPolygon.title = "Fläche zeichnen"
      drawPolygon.addEventListener("click", e => {
        e.preventDefault()
        this.startDrawing(window.vcs.GeometryType.Polygon)
      })
      container.appendChild(drawPolygon)
    }

    this.addClearMapControl(container)

    this.container.appendChild(container)
    this.startDrawing(window.vcs.GeometryType.Point)

    if (this.featuresLimit > 1) {
      this.showFeatureLimitHint(this.featuresLimit)
    }
  }

  addClearMapControl(container) {
    const clear = document.createElement("button")
    clear.type = "button"
    clear.innerHTML = '<span class="material-symbols-outlined">delete</span>'
    clear.title = "Karte zurücksetzen"
    clear.addEventListener("click", e => {
      e.preventDefault()
      this.clearEditableFeatures()
    })
    container.appendChild(clear)
  }

  setupEditableFeatureListeners(layer) {
    // VCS handles feature editing internally via sessions
  }

  onFeatureCreated(event) {
    // Handled in startDrawing session listeners
  }

  startDrawing(geometryType) {
    if (!this.vcsApp || !window.vcs) return

    const layer = this.getOrCreateLayer("_editorLayer")
    layer.activate()

    const session = window.vcs.startCreateFeatureSession(this.vcsApp, layer, geometryType)

    session.featureCreated.addEventListener(feature => {
      // Enforce feature limit
      if (!this.adminEditor && layer.getFeatures().length > this.featuresLimit) {
        const features = layer.getFeatures()
        layer.removeFeaturesById([features[0].getId()])
      }
      this.styleEditorFeature(feature)
    })

    session.creationFinished.addEventListener(feature => {
      if (!feature) return
      this.setFeatureData(feature)
      if (this.callbacks.onCreate) this.callbacks.onCreate({ feature })
    })
  }

  styleEditorFeature(feature) {
    const geometry = feature.getGeometry()

    if (geometry instanceof window.ol.geom.Polygon) {
      feature.set("olcs_altitudeMode", "relativeToGround")
      const style = new window.vcs.VectorStyleItem({})
      style.fillColor = hexToRgba(this.defaultFeatureColor, 0.3)
      style.stroke = new window.ol.style.Stroke({ color: this.defaultFeatureColor, width: 2 })
      feature.setStyle(style.style)
    } else if (geometry instanceof window.ol.geom.Point) {
      const style = new window.vcs.VectorStyleItem({})
      style.image = new window.ol.style.Icon({ src: this.buildPinSvg(this.defaultFeatureColor) })
      feature.setStyle(style.style)
    }
  }

  setFeatureData(feature) {
    const geometry = feature.getGeometry()

    if (geometry instanceof window.ol.geom.Point) {
      const [lng, lat, alt] = window.vcs.Projection.mercatorToWgs84(geometry.getCoordinates())
      feature.data = { lat, lng, alt }
    } else if (geometry instanceof window.ol.geom.Polygon) {
      const coords = geometry.getLinearRing(0).getCoordinates()
        .map(c => window.vcs.Projection.mercatorToWgs84(c))
      feature.data = {
        type: "Feature",
        geometry: { type: "Polygon", coordinates: [coords] },
        properties: {}
      }
    }
  }

  // ===========================================================================
  // 7. FORM INPUT SYNCHRONIZATION
  // ===========================================================================

  onMapChange(callbacks) {
    this.callbacks = { ...this.callbacks, ...callbacks }

    // Set up camera change listener when map is ready
    this.onCesiumMapReady(map => {
      this.setupCameraChangeListener(map)
    })
  }

  setupCameraChangeListener(map) {
    const cesiumWidget = map.getCesiumWidget?.() || map.cesiumWidget
    if (!cesiumWidget?.scene) return

    let lastUpdate = 0
    const throttleMs = 100

    // Use scene postRender to detect camera changes
    cesiumWidget.scene.postRender.addEventListener(() => {
      const now = Date.now()
      if (now - lastUpdate < throttleMs) return
      lastUpdate = now

      this.updateCenterFromViewpoint(map)
    })
  }

  updateCenterFromViewpoint(map) {
    map.getViewpoint().then(viewpoint => {
      if (!viewpoint?.groundPosition) return

      const [lng, lat] = viewpoint.groundPosition
      const distance = viewpoint.distance

      // Update stored values
      this.currentCenter = { lat, lng }
      this.currentZoom = this.distanceToZoom(distance)

      if (this.callbacks.onMove) {
        this.callbacks.onMove(this.currentCenter, this.currentZoom)
      }
    }).catch(() => {
      // Ignore errors when getting viewpoint
    })
  }

  distanceToZoom(distance) {
    // Reverse lookup from ZOOM_DISTANCE_MATRIX
    const matrix = VirtualCityAdapter.ZOOM_DISTANCE_MATRIX
    let closestZoom = 6 // Default to widest zoom

    for (const [zoom, dist] of Object.entries(matrix).sort((a, b) => b[1] - a[1])) {
      if (distance <= dist) {
        closestZoom = parseInt(zoom)
      }
    }

    return closestZoom
  }

  getEditableFeatures() {
    const layer = this.vcsApp?.layers.getByKey("_editorLayer")
    if (!layer) return { type: "FeatureCollection", features: [] }

    const features = layer.getFeatures()
      .map(f => this.featureToGeoJSON(f))
      .filter(Boolean)

    return { type: "FeatureCollection", features }
  }

  clearEditableFeatures() {
    this.vcsApp?.layers.getByKey("_editorLayer")?.removeAllFeatures()
    this.editableLayers = []
    if (this.callbacks.onClear) this.callbacks.onClear()
  }

  featureToGeoJSON(feature) {
    const geometry = feature.getGeometry()

    if (geometry instanceof window.ol.geom.Point) {
      return {
        type: "Feature",
        geometry: {
          type: "Point",
          coordinates: window.vcs.Projection.mercatorToWgs84(geometry.getCoordinates())
        },
        properties: feature.data || {}
      }
    }

    if (geometry instanceof window.ol.geom.Polygon) {
      return {
        type: "Feature",
        geometry: {
          type: "Polygon",
          coordinates: [geometry.getLinearRing(0).getCoordinates().map(c =>
            window.vcs.Projection.mercatorToWgs84(c)
          )]
        },
        properties: feature.data || {}
      }
    }

    return null
  }

  // ===========================================================================
  // 8. MAP STATE GETTERS/SETTERS
  // ===========================================================================

  getCenter() {
    return this.currentCenter || { lat: this.options.latitude, lng: this.options.longitude }
  }

  getZoom() {
    return this.currentZoom || this.options.zoom
  }

  getAltitude() {
    return this.options.altitude || 0
  }

  setView(lat, lng, zoom) {
    this.withCesiumMap(map => {
      map.gotoViewpoint(this.createViewpoint(lng, lat, zoom))
    })
  }

  // ===========================================================================
  // 9. UI/UX HELPERS
  // ===========================================================================

  showFeatureLimitHint(limit) {
    const hint = document.createElement("div")
    hint.className = "controls feature-limit-hint"
    hint.style.cssText = "bottom: 10px; left: 10px; color: #ff0000; font-size: 12px; background: rgba(255,255,255,0.9); padding: 4px 8px; border-radius: 4px;"
    hint.textContent = `Sie dürfen insgesamt ${limit} Pins setzen.`
    this.container.appendChild(hint)
  }

  getDefaultFeatureColor(isAdmin = false) {
    if (isAdmin) return "#ff0000"
    return getBrandColor()
  }

  invalidateSize() {
    this.withCesiumMap(map => {
      const widget = map.getCesiumWidget?.() || map.cesiumWidget
      widget?.resize?.()
    })
  }

  setFeatureStyle(color, iconName, categoryName) {
    this.featureColor = color
    this.featureIconName = iconName
    this.featureCategoryName = categoryName
    this.defaultFeatureColor = color || this.getDefaultFeatureColor(this.adminEditor)
  }

  // ===========================================================================
  // 10. VCS-SPECIFIC HELPERS
  // ===========================================================================

  withCesiumMap(callback) {
    const map = this.vcsApp?.maps?.activeMap
    if (map?.className === "CesiumMap") {
      callback(map)
    }
  }

  onCesiumMapReady(callback) {
    if (!this.vcsApp) return

    const map = this.vcsApp.maps.activeMap
    if (map?.className === "CesiumMap") {
      callback(map)
    }
    this.mapActivatedHandlers.push(callback)
  }

  setDefaultView(map) {
    map.gotoViewpoint(this.createViewpoint(
      this.options.longitude,
      this.options.latitude,
      this.options.zoom
    ))
  }

  createViewpoint(lng, lat, zoom) {
    return new window.vcs.Viewpoint({
      groundPosition: [lng, lat],
      distance: VirtualCityAdapter.ZOOM_DISTANCE_MATRIX[zoom] || 9600,
      pitch: -35,
      animate: true
    })
  }

  setupFeatureInfoSession() {
    if (this.featureInfoSession) return
    if (MapPopup.excludedProcesses.includes(this.options.process)) return
    if (this.options.editable) return

    const instance = this
    const app = this.vcsApp

    class FeatureInfoInteraction extends window.vcs.AbstractInteraction {
      constructor() {
        super(window.vcs.EventType.CLICK, window.vcs.ModificationKeyType.NONE)
        this.setActive()
      }

      pipe(event) {
        if (event.feature?.resource_id) {
          instance.showFeatureInfo(event.feature)
        }
        return event
      }
    }

    const eventHandler = app.maps.eventHandler
    const interaction = new FeatureInfoInteraction()
    const prevInteractionEvent = eventHandler.featureInteraction.active

    const listener = eventHandler.addExclusiveInteraction(interaction, () => this.featureInfoSession?.stop())
    eventHandler.featureInteraction.setActive(window.vcs.EventType.CLICK)

    const stopped = new window.vcs.VcsEvent()
    this.featureInfoSession = {
      stopped,
      stop: () => {
        listener()
        interaction.destroy()
        eventHandler.featureInteraction.setActive(prevInteractionEvent)
        stopped.raiseEvent()
        stopped.destroy()
      }
    }
  }

  showFeatureInfo(feature) {
    const resourceType = feature.data?.resource_type
    const url = MapPopup.getPopupDataUrl(resourceType, feature.data)
    if (!url) return

    fetch(url)
      .then(r => r.json())
      .then(data => {
        this.showPopup(MapPopup.generatePopupContent(data, resourceType, feature.data))
      })
      .catch(e => console.error("Failed to load feature info:", e))
  }

  showPopup(html) {
    this.container.querySelector("#vc-popup")?.remove()

    const popup = document.createElement("div")
    popup.id = "vc-popup"

    const closeButton = document.createElement("button")
    closeButton.className = "popup-close-button"
    closeButton.innerHTML = "×"
    closeButton.onclick = () => popup.remove()

    const content = document.createElement("div")
    content.id = "vc-popup-content"
    content.innerHTML = html

    popup.append(closeButton, content)
    this.container.appendChild(popup)
  }
}

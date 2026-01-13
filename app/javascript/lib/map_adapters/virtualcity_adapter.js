import BaseAdapter from "./base_adapter"

/**
 * Virtual City Map adapter for 3D map rendering.
 * Uses the VCS (Virtual City Systems) framework loaded externally.
 */
export default class VirtualCityAdapter extends BaseAdapter {
  initialize(container, options) {
    this.container = container
    this.options = options
    this.vcsApp = null
    this.callbacks = {}
    this.defaultFeatureColor = "#ff0000"

    this.initializeVcsApp()
  }

  destroy() {
    if (this.vcsApp) {
      // VCS cleanup if needed
      this.vcsApp = null
    }
  }

  getCenter() {
    // VCS uses different coordinate handling
    return {
      lat: this.options.latitude,
      lng: this.options.longitude
    }
  }

  getZoom() {
    return this.options.zoom
  }

  getAltitude() {
    return this.options.altitude || 0
  }

  setView(lat, lng, zoom) {
    if (!this.vcsApp) return

    const activeMap = this.vcsApp.maps.activeMap
    if (activeMap && activeMap.className === "CesiumMap") {
      activeMap.gotoViewPoint({
        groundPosition: [lng, lat],
        distance: this.zoomToDistance(zoom),
        pitch: -45,
        heading: 0
      })
    }
  }

  addFeatures(features, options = {}) {
    if (!this.vcsApp || !features || Object.keys(features).length === 0) return

    this.vcsApp.maps.mapActivated.addEventListener((map) => {
      if (map.className === "CesiumMap") {
        this.drawFeatures(features, "_editorLayer")
      }
    })
  }

  getEditableFeatures() {
    if (!this.vcsApp) {
      return { type: "FeatureCollection", features: [] }
    }

    // Get features from editor layer
    const layer = this.vcsApp.layers.getByKey("_editorLayer")
    if (!layer) {
      return { type: "FeatureCollection", features: [] }
    }

    const features = []
    layer.getFeatures().forEach(feature => {
      features.push(feature.toGeoJSON())
    })

    return {
      type: "FeatureCollection",
      features
    }
  }

  clearEditableFeatures() {
    if (!this.vcsApp) return

    const layer = this.vcsApp.layers.getByKey("_editorLayer")
    if (layer) {
      layer.removeAllFeatures()
    }
  }

  enableEditing(options = {}) {
    if (!this.vcsApp) return

    this.vcsApp.maps.mapActivated.addEventListener((map) => {
      if (map.className === "CesiumMap") {
        this.enableDrawing()
      }
    })
  }

  onMapChange(callbacks) {
    this.callbacks = { ...this.callbacks, ...callbacks }

    if (!this.vcsApp) return

    // VCS map change events
    this.vcsApp.maps.mapActivated.addEventListener((map) => {
      if (map.className === "CesiumMap") {
        map.getScene().camera.changed.addEventListener(() => {
          if (callbacks.onMove) {
            const position = this.getCameraPosition(map)
            callbacks.onMove(position, this.getZoom())
          }
        })
      }
    })
  }

  setupLayers(layers) {
    // VCS layers are typically configured via the config.json
    // TODO: Implement dynamic layer support if needed
  }

  addAdminFeatures(features) {
    if (!this.vcsApp || !features || Object.keys(features).length === 0) return

    this.vcsApp.maps.mapActivated.addEventListener((map) => {
      if (map.className === "CesiumMap") {
        this.drawFeatures(features, "_adminShapeLayer", { editable: false })
      }
    })
  }

  // Private methods

  initializeVcsApp() {
    if (!window.vcs) {
      console.warn("VCS library not loaded. Make sure vcmap-core.js is included.")
      return
    }

    this.vcsApp = new window.vcs.VcsApp()
    this.vcsApp.maps.setTarget(this.container)

    // Load VCS config
    this.loadVcsConfig()

    // Set CESIUM_BASE_URL
    window.CESIUM_BASE_URL = "/vcmap/assets/cesium/"

    // Store reference globally for debugging
    window.vcsApp = this.vcsApp
  }

  async loadVcsConfig() {
    try {
      const response = await fetch("https://new.virtualcitymap.de/map.config.json")
      const config = await response.json()

      // Apply config
      await this.vcsApp.addModule(new window.vcs.VcsModule(config))

      // Set initial view after map is ready
      this.vcsApp.maps.mapActivated.addEventListener((map) => {
        if (map.className === "CesiumMap") {
          this.setInitialView(map)
        }
      })
    } catch (error) {
      console.error("Failed to load VCS config:", error)
    }
  }

  setInitialView(map) {
    map.gotoViewPoint({
      groundPosition: [this.options.longitude, this.options.latitude],
      distance: this.zoomToDistance(this.options.zoom),
      pitch: -45,
      heading: 0
    })
  }

  zoomToDistance(zoom) {
    // Convert zoom level to camera distance
    // This is an approximation
    return 40000000 / Math.pow(2, zoom)
  }

  getCameraPosition(map) {
    const camera = map.getScene().camera
    const position = camera.positionCartographic
    return {
      lat: Cesium.Math.toDegrees(position.latitude),
      lng: Cesium.Math.toDegrees(position.longitude)
    }
  }

  drawFeatures(geojson, layerKey, options = {}) {
    if (!this.vcsApp) return

    let layer = this.vcsApp.layers.getByKey(layerKey)
    if (!layer) {
      layer = new window.vcs.VectorLayer({
        name: layerKey,
        projection: { epsg: 4326 }
      })
      this.vcsApp.layers.add(layer)
      layer.activate()
    }

    const features = geojson.features || [geojson]
    features.forEach(feature => {
      const vcsFeature = new window.vcs.Feature(feature)
      layer.addFeatures([vcsFeature])
    })
  }

  enableDrawing() {
    if (!this.vcsApp || !window.vcs) return

    // Enable point drawing by default
    const session = this.vcsApp.startDrawSession(window.vcs.GeometryType.Point)

    session.featureCreated.addEventListener((feature) => {
      const layer = this.vcsApp.layers.getByKey("_editorLayer") ||
                    this.createEditorLayer()

      layer.addFeatures([feature])

      if (this.callbacks.onCreate) {
        this.callbacks.onCreate({ feature: feature.toGeoJSON() })
      }
    })
  }

  createEditorLayer() {
    const layer = new window.vcs.VectorLayer({
      name: "_editorLayer",
      projection: { epsg: 4326 }
    })
    this.vcsApp.layers.add(layer)
    layer.activate()
    return layer
  }
}

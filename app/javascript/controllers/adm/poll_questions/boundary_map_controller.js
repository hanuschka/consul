import { Controller } from "@hotwired/stimulus"

const LEAFLET_DRAW_TOOL = "Polygon"
const MAPBOX_DRAW_MODE = "draw_polygon"
const POLYGON_TYPES = ["Polygon", "MultiPolygon"]
const MAX_POLYGONS = 250
const FIT_PADDING = 20

export default class extends Controller {
  static targets = ["file", "status"]

  static values = {
    maxFileSize: Number,
    messages: Object
  }

  async configureMap(event) {
    this.adapter = event.detail.adapter
    if (!this.adapter) return

    await this.mapReady()

    this.adapter.featuresLimit = Infinity
    this.armPolygonTool()
  }

  async importFile() {
    const file = this.fileTarget.files[0]
    if (!file) return

    if (!this.adapter) {
      this.reset(this.messagesValue.map_missing)
      return
    }

    if (file.size > this.maxFileSizeValue) {
      this.reset(this.messagesValue.too_large)
      return
    }

    let polygons

    try {
      polygons = this.polygonsFrom(JSON.parse(await file.text()))
    } catch (error) {
      this.reset(this.messagesValue.invalid_file)
      return
    }

    if (polygons.length === 0) {
      this.reset(this.messagesValue.no_polygons)
      return
    }

    if (polygons.length > MAX_POLYGONS) {
      this.reset(this.messagesValue.too_many)
      return
    }

    await this.replaceFeatures({ type: "FeatureCollection", features: polygons })
    this.reset(this.messagesValue.imported)
  }

  polygonsFrom(parsed) {
    let features = []

    if (Array.isArray(parsed.features)) {
      features = parsed.features
    } else if (POLYGON_TYPES.includes(parsed.type)) {
      features = [{ geometry: parsed }]
    } else {
      features = [parsed]
    }

    return features
      .filter((feature) => POLYGON_TYPES.includes(feature && feature.geometry && feature.geometry.type))
      .map((feature) => ({ type: "Feature", properties: {}, geometry: feature.geometry }))
  }

  async replaceFeatures(collection) {
    this.adapter.clearEditableFeatures()
    this.adapter.addFeatures(collection, { editable: true })

    await this.mapReady()

    const input = this.element.querySelector("[data-map-target='features']")
    if (input) input.value = JSON.stringify(this.adapter.getEditableFeatures())

    this.fitTo(collection)
  }

  /**
   * Mapbox builds its map and draw controls behind a promise; Leaflet is
   * synchronous and exposes no such promise, so this resolves immediately there.
   */
  mapReady() {
    return Promise.resolve(this.adapter && this.adapter.mapLoaded)
  }

  get usesMapbox() {
    const container = this.adapter && this.adapter.container

    return !!container && container._mapLibrary === "mapbox"
  }

  armPolygonTool() {
    const map = this.adapter.map
    if (!map) return

    if (this.usesMapbox) {
      if (this.adapter.draw) this.adapter.draw.changeMode(MAPBOX_DRAW_MODE)
    } else if (map.pm) {
      map.pm.disableDraw()
      map.pm.enableDraw(LEAFLET_DRAW_TOOL)
    }
  }

  fitTo(collection) {
    const map = this.adapter.map
    const bounds = this.boundsOf(collection)

    if (!map || !bounds) return

    const [[minLng, minLat], [maxLng, maxLat]] = bounds

    if (this.usesMapbox) {
      map.fitBounds([[minLng, minLat], [maxLng, maxLat]], { padding: FIT_PADDING })
    } else {
      map.fitBounds([[minLat, minLng], [maxLat, maxLng]], { padding: [FIT_PADDING, FIT_PADDING] })
    }
  }

  /**
   * Bounding box of a polygon collection as [[minLng, minLat], [maxLng, maxLat]],
   * computed here so neither map library has to be loaded to frame an import.
   */
  boundsOf(collection) {
    let minLng = Infinity
    let minLat = Infinity
    let maxLng = -Infinity
    let maxLat = -Infinity

    const visit = (coordinates) => {
      if (typeof coordinates[0] === "number") {
        const [lng, lat] = coordinates

        if (!isFinite(lng) || !isFinite(lat)) return

        minLng = Math.min(minLng, lng)
        minLat = Math.min(minLat, lat)
        maxLng = Math.max(maxLng, lng)
        maxLat = Math.max(maxLat, lat)

        return
      }

      coordinates.forEach(visit)
    }

    collection.features.forEach((feature) => visit(feature.geometry.coordinates))

    if (minLng === Infinity) return null

    return [[minLng, minLat], [maxLng, maxLat]]
  }

  reset(message) {
    this.fileTarget.value = ""
    this.setStatus(message)
  }

  setStatus(message) {
    this.statusTarget.textContent = message || ""
  }
}

import { Controller } from "@hotwired/stimulus"

const DRAW_TOOL = "Polygon"
const POLYGON_TYPES = ["Polygon", "MultiPolygon"]
const MAX_POLYGONS = 250

export default class extends Controller {
  static targets = ["file", "status"]

  static values = {
    maxFileSize: Number,
    messages: Object
  }

  configureMap(event) {
    this.adapter = event.detail.adapter
    if (!this.adapter) return

    this.adapter.featuresLimit = Infinity
    this.adapter.map.pm.disableDraw()
    this.adapter.map.pm.enableDraw(DRAW_TOOL)
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

    this.replaceFeatures({ type: "FeatureCollection", features: polygons })
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

  replaceFeatures(collection) {
    this.adapter.clearEditableFeatures()
    this.adapter.addFeatures(collection, { editable: true })

    const input = this.element.querySelector("[data-map-target='features']")
    if (input) input.value = JSON.stringify(this.adapter.getEditableFeatures())

    const bounds = window.L.geoJSON(collection).getBounds()
    if (bounds.isValid()) this.adapter.map.fitBounds(bounds, { padding: [20, 20] })
  }

  reset(message) {
    this.fileTarget.value = ""
    this.setStatus(message)
  }

  setStatus(message) {
    this.statusTarget.textContent = message || ""
  }
}

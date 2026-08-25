import { Controller } from "@hotwired/stimulus"

const LEAFLET_JS = "https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"

const DEFAULT_CENTER = [51.163, 10.447]
const DEFAULT_ZOOM = 12

const HEAT_OPTIONS = {
  radius: 40,
  blur: 22,
  minOpacity: 0.45,
  max: 1.0,
  gradient: {
    0.0: "rgba(0, 150, 255, 0.7)",
    0.3: "rgba(0, 255, 200, 0.75)",
    0.5: "rgba(255, 255, 0, 0.8)",
    0.7: "rgba(255, 150, 0, 0.85)",
    1.0: "rgba(255, 0, 0, 0.9)"
  }
}

let scriptsPromise = null

const loadScript = (src) =>
  new Promise((resolve, reject) => {
    const existing = document.querySelector(`script[src="${src}"]`)

    if (existing) {
      if (existing.dataset.loaded === "true") {
        resolve()
      } else {
        existing.addEventListener("load", () => resolve())
        existing.addEventListener("error", reject)
      }

      return
    }

    const script = document.createElement("script")
    script.src = src
    script.async = false
    script.addEventListener("load", () => {
      script.dataset.loaded = "true"
      resolve()
    })
    script.addEventListener("error", reject)
    document.head.appendChild(script)
  })

const loadLeaflet = () => {
  if (scriptsPromise) return scriptsPromise

  scriptsPromise = (async () => {
    if (typeof window.L === "undefined") await loadScript(LEAFLET_JS)
    if (typeof window.L.heatLayer !== "function") await import("leaflet.heat/dist/leaflet-heat")
  })()

  return scriptsPromise
}

export default class extends Controller {
  static values = {
    coordinates: Array,
    center: Array,
    zoom: Number,
    emptyText: String
  }

  connect() {
    if (this.coordinatesValue.length === 0) {
      this.renderEmpty()

      return
    }

    loadLeaflet()
      .then(() => this.initMap())
      .catch(() => this.renderEmpty())
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
      this.map = null
    }
  }

  initMap() {
    if (this.map) return

    const L = window.L
    const zoomLimits = window.App.MapZoom
    const center = this.centerValue.length === 2 ? this.centerValue : DEFAULT_CENTER
    const zoom = this.zoomValue || DEFAULT_ZOOM

    this.map = L.map(this.element, {
      scrollWheelZoom: false,
      zoomControl: true,
      maxZoom: zoomLimits.MAX
    }).setView(center, zoom)

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; <a href=\"https://www.openstreetmap.org/copyright\">OpenStreetMap</a>",
      maxZoom: zoomLimits.MAX,
      maxNativeZoom: zoomLimits.MAX_NATIVE_TILE
    }).addTo(this.map)

    L.heatLayer(this.coordinatesValue, HEAT_OPTIONS).addTo(this.map)

    requestAnimationFrame(() => this.map.invalidateSize())
  }

  renderEmpty() {
    const message = document.createElement("p")
    message.className = "phase-heatmap__empty"
    message.textContent = this.emptyTextValue
    this.element.appendChild(message)
  }
}

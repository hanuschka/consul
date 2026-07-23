import { Controller } from "@hotwired/stimulus"
import LeafletAdapter from "../lib/map_adapters/leaflet_adapter"
import MapboxAdapter from "../lib/map_adapters/mapbox_adapter"
import VirtualCityAdapter from "../lib/map_adapters/virtualcity_adapter"

/**
 * Map Controller
 *
 * Generic map controller for all map rendering scenarios:
 * - Admin settings (defining default map location and admin shapes)
 * - User-editable maps (e.g., creating proposals with map locations)
 * - Read-only display maps (viewing proposals)
 *
 * Uses adapters for different rendering libraries (leaflet, mapbox, virtualcity).
 * Set editable=false for read-only maps, editable=true for user editing.
 */
export default class extends Controller {
  static targets = ["container", "latitude", "longitude", "altitude", "zoom", "features", "mapboxStyleField"]

  static values = {
    renderingLibrary: { type: String, default: "leaflet" },
    latitude: { type: Number, default: 53.551086 },
    longitude: { type: Number, default: 9.993682 },
    zoom: { type: Number, default: 13 },
    altitude: { type: Number, default: 0 },
    editable: { type: Boolean, default: true },
    gestureHandling: { type: Boolean, default: true },
    adminEditor: { type: Boolean, default: false },
    enableSetCenter: { type: Boolean, default: false },
    features: { type: Object, default: {} },
    adminFeatures: { type: Object, default: {} },
    layers: { type: Array, default: [] },
    mapboxPublicToken: { type: String, default: "" },
    mapboxStyleId: { type: String, default: "" },
    masterportalDefaultIconUrl: { type: String, default: "" },
    vcMapModuleUrl: { type: String, default: "" }
  }

  async connect() {
    this.adapter = this.createAdapter()

    await this.adapter.initialize(this.containerTarget, this.mapOptions)
    this.adapter.setupLayers(this.layersValue)

    if (this.adminFeaturesValue && Object.keys(this.adminFeaturesValue).length > 0) {
      this.adapter.addAdminFeatures(this.adminFeaturesValue)
    }

    // Enable editing first so draw controls exist before adding features
    if (this.editableValue) {
      this.adapter.enableEditing()
    }

    if (this.enableSetCenterValue) {
      this.adapter.addSetCenterControl()
    }

    if (this.featuresValue && Object.keys(this.featuresValue).length > 0) {
      this.adapter.addFeatures(this.featuresValue, { editable: this.editableValue })
    }

    this.setupFormSync()
    this.setupFeatureStyleListeners()

    // Expose map instance for screenshot functionality
    this.containerTarget._mapAdapter = this.adapter
    this.containerTarget._mapLibrary = this.renderingLibraryValue
  }

  disconnect() {
    if (this._featureStyleChangeHandler) {
      document.removeEventListener("change", this._featureStyleChangeHandler)
    }
    if (this.adapter) {
      this.adapter.destroy()
      this.adapter = null
    }
  }

  /**
   * Create the appropriate adapter based on rendering library
   */
  createAdapter() {
    switch (this.renderingLibraryValue) {
      case "mapbox":
        return new MapboxAdapter()
      case "virtualcity":
        return new VirtualCityAdapter()
      default:
        return new LeafletAdapter()
    }
  }

  /**
   * Map options to pass to the adapter
   */
  get mapOptions() {
    return {
      latitude: this.latitudeValue,
      longitude: this.longitudeValue,
      zoom: this.zoomValue,
      altitude: this.altitudeValue,
      editable: this.editableValue,
      gestureHandling: this.gestureHandlingValue,
      adminEditor: this.adminEditorValue,
      enableSetCenter: this.enableSetCenterValue,
      masterportalEnabled: this.renderingLibraryValue === "leaflet_plus_masterportal",
      masterportalDefaultIconUrl: this.masterportalDefaultIconUrlValue,
      mapboxPublicToken: this.mapboxPublicTokenValue,
      mapboxStyleId: this.mapboxStyleIdValue,
      vcMapModuleUrl: this.vcMapModuleUrlValue
    }
  }

  /**
   * Set up synchronization between map and form inputs
   */
  setupFormSync() {
    this.adapter.onMapChange({
      onMove: (center, zoom) => {
        this.updateLatLngInputs(center)
        this.updateZoomInput(zoom)
      },
      onZoom: (zoom) => {
        this.updateZoomInput(zoom)
      },
      onCreate: () => {
        this.updateFeaturesInput()
      },
      onEdit: () => {
        this.updateFeaturesInput()
      },
      onClear: () => {
        this.updateFeaturesInput()
      }
    })
  }

  /**
   * Update latitude/longitude form inputs
   */
  updateLatLngInputs(center) {
    if (this.hasLatitudeTarget) {
      this.latitudeTarget.value = center.lat.toFixed(6)
    }
    if (this.hasLongitudeTarget) {
      this.longitudeTarget.value = center.lng.toFixed(6)
    }
  }

  /**
   * Update zoom form input
   */
  updateZoomInput(zoom) {
    if (this.hasZoomTarget) {
      this.zoomTarget.value = zoom
    }
  }

  /**
   * Update altitude form input (for 3D maps)
   */
  updateAltitudeInput(altitude) {
    if (this.hasAltitudeTarget) {
      this.altitudeTarget.value = altitude
    }
  }

  /**
   * Update features form input with current editable features
   */
  updateFeaturesInput() {
    if (!this.hasFeaturesTarget) return

    const features = this.adapter.getEditableFeatures()
    this.featuresTarget.value = JSON.stringify(features)
  }

  /**
   * Action: Clear all editable features
   */
  clearFeatures() {
    this.adapter.clearEditableFeatures()
    this.updateFeaturesInput()
  }

  /**
   * Set up listeners for feature style changes via DOM event delegation.
   * Listens for "change" events on inputs within [data-feature-style-mode] containers.
   * Reads icon and color from checked input labels' data attributes.
   */
  setupFeatureStyleListeners() {
    if (!this.editableValue) return

    this._featureStyle = { color: null, iconName: null, iconUnicode: null }

    // Read initial state from DOM (handles edit page with pre-selected values)
    this.readFeatureStyleFromDOM()

    this._featureStyleChangeHandler = (event) => {
      const container = event.target.closest("[data-feature-style-mode]")
      if (!container) return

      this.readFeatureStyleFromDOM()
    }
    document.addEventListener("change", this._featureStyleChangeHandler)
  }

  /**
   * Read current feature style from checked inputs in the DOM.
   * Queries [data-feature-style-mode="icon"] and [data-feature-style-mode="color"]
   * containers in the document (labels/sentiments may be outside the map element).
   */
  readFeatureStyleFromDOM() {
    const iconContainer = document.querySelector('[data-feature-style-mode="icon"]')
    if (iconContainer) {
      const checked = iconContainer.querySelectorAll("input:checked")
      const labels = Array.from(checked).map(input => {
        return iconContainer.querySelector(`label[for="${input.id}"]`)
      }).filter(Boolean)

      if (labels.length === 1) {
        this._featureStyle.iconName = labels[0].dataset.iconName || null
        this._featureStyle.iconUnicode = labels[0].dataset.iconUnicode || null
      } else if (labels.length > 1) {
        this._featureStyle.iconName = "tags"
        this._featureStyle.iconUnicode = "f02c"
      } else {
        this._featureStyle.iconName = null
        this._featureStyle.iconUnicode = null
      }
    }

    const colorContainer = document.querySelector('[data-feature-style-mode="color"]')
    if (colorContainer) {
      const checked = colorContainer.querySelector("input:checked")
      const label = checked ? colorContainer.querySelector(`label[for="${checked.id}"]`) : null
      this._featureStyle.color = label?.dataset.color || null
    }

    this.applyFeatureStyle()
  }

  applyFeatureStyle() {
    if (!this._featureStyle) return

    const { color, iconName, iconUnicode } = this._featureStyle
    this.adapter.setFeatureStyle(color, iconName, iconUnicode, null)
  }

  /**
   * Action: Switch rendering library while preserving form state
   */
  async switchRenderingLibrary(event) {
    const newLibrary = event.target.value
    if (newLibrary === this.renderingLibraryValue) return

    // Save current state from form inputs
    const savedState = {
      latitude: this.hasLatitudeTarget ? parseFloat(this.latitudeTarget.value) : this.latitudeValue,
      longitude: this.hasLongitudeTarget ? parseFloat(this.longitudeTarget.value) : this.longitudeValue,
      zoom: this.hasZoomTarget ? parseFloat(this.zoomTarget.value) : this.zoomValue,
      altitude: this.hasAltitudeTarget ? parseFloat(this.altitudeTarget.value) : this.altitudeValue,
      features: this.hasFeaturesTarget ? this.featuresTarget.value : "{}"
    }

    // Destroy old adapter
    if (this.adapter) {
      this.adapter.destroy()
      this.adapter = null
    }

    // Update container class for library-specific styles
    this.containerTarget.classList.remove("leaflet", "mapbox", "virtualcity")
    this.containerTarget.classList.add(newLibrary)

    // Update rendering library value
    this.renderingLibraryValue = newLibrary

    // Toggle mapbox style field visibility
    if (this.hasMapboxStyleFieldTarget) {
      this.mapboxStyleFieldTarget.classList.toggle("d-none", newLibrary !== "mapbox")
    }

    // Create and initialize new adapter with saved state
    this.adapter = this.createAdapter()

    const options = {
      ...this.mapOptions,
      latitude: savedState.latitude,
      longitude: savedState.longitude,
      zoom: savedState.zoom,
      altitude: savedState.altitude
    }

    await this.adapter.initialize(this.containerTarget, options)
    this.adapter.setupLayers(this.layersValue)

    // Enable editing first so draw controls exist before adding features
    if (this.editableValue) {
      this.adapter.enableEditing()
    }

    if (this.enableSetCenterValue) {
      this.adapter.addSetCenterControl()
    }

    // Restore features
    const features = JSON.parse(savedState.features || "{}")
    if (features && Object.keys(features).length > 0) {
      this.adapter.addFeatures(features, { editable: this.editableValue })
    }

    this.setupFormSync()
    this.setupFeatureStyleListeners()
  }
}

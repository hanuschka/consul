/**
 * Base adapter class defining the interface for map rendering libraries.
 * All map adapters (Leaflet, Mapbox, VirtualCity) must implement these methods.
 */
export default class BaseAdapter {
  constructor() {
    this.map = null
    this.baseLayers = {}
    this.overlayLayers = {}
    this.editableLayers = []
    this.clusterGroup = null
    this.callbacks = {}
  }

  // ===========================================================================
  // 1. INITIALIZATION & CONFIGURATION
  // ===========================================================================

  /**
   * Initialize the map in the given container
   * @param {HTMLElement} container - The DOM element to render the map in
   * @param {Object} options - Map configuration options
   * @param {Number} options.latitude - Initial center latitude
   * @param {Number} options.longitude - Initial center longitude
   * @param {Number} options.zoom - Initial zoom level
   * @param {Number} options.altitude - Initial altitude (for 3D maps)
   * @param {Boolean} options.editable - Whether editing is enabled
   */
  initialize(container, options) {
    throw new Error("Subclass must implement initialize()")
  }

  /**
   * Destroy the map instance and clean up resources
   */
  destroy() {
    throw new Error("Subclass must implement destroy()")
  }

  /**
   * Re-layout the map when its container becomes visible. A map created inside
   * a hidden container gets a zero-sized viewport and stays broken otherwise.
   */
  observeContainerResize() {
    if (typeof ResizeObserver === "undefined" || !this.container) return

    this._containerVisible = this.container.offsetWidth > 0

    this._containerResizeObserver = new ResizeObserver(() => {
      const visible = this.container.offsetWidth > 0

      if (visible && !this._containerVisible) this.invalidateSize()

      this._containerVisible = visible
    })

    this._containerResizeObserver.observe(this.container)
  }

  /**
   * Stop watching the container for visibility changes
   */
  stopObservingContainerResize() {
    if (!this._containerResizeObserver) return

    this._containerResizeObserver.disconnect()
    this._containerResizeObserver = null
  }

  // ===========================================================================
  // 2. MAP CREATION & CONTROLS
  // ===========================================================================

  /**
   * Create the map instance with default controls (zoom, etc.)
   * @param {HTMLElement} container
   * @param {Object} options
   */
  createMap(container, options) {
    throw new Error("Subclass must implement createMap()")
  }

  /**
   * Set up the fullscreen/expand toggle control
   */
  setupExpandControl() {
    throw new Error("Subclass must implement setupExpandControl()")
  }

  /**
   * Toggle visibility of controls based on map size
   * (hide controls on small screens)
   */
  toggleControlVisibility() {
    throw new Error("Subclass must implement toggleControlVisibility()")
  }

  // ===========================================================================
  // 3. LAYER MANAGEMENT
  // ===========================================================================

  /**
   * Set up base and overlay layers from configuration
   * @param {Array} layers - Layer configuration array
   */
  setupLayers(layers) {
    throw new Error("Subclass must implement setupLayers()")
  }

  /**
   * Create a single layer from configuration
   * @param {Object} layerConfig - Layer configuration object
   * @param {String} layerConfig.name - Layer name
   * @param {String} layerConfig.provider - Tile URL or WMS endpoint
   * @param {String} layerConfig.protocol - 'wms' or 'xyz'
   * @param {Boolean} layerConfig.base - Whether this is a base layer
   * @param {Boolean} layerConfig.transparent - For WMS layers
   * @param {Boolean} layerConfig.show_by_default - Auto-add overlay to map
   */
  createLayer(layerConfig) {
    throw new Error("Subclass must implement createLayer()")
  }

  /**
   * Ensure at least one base layer exists (fallback to OSM)
   */
  ensureBaseLayerExists() {
    throw new Error("Subclass must implement ensureBaseLayerExists()")
  }

  /**
   * Add layer switcher control to the map
   */
  addLayerControl() {
    throw new Error("Subclass must implement addLayerControl()")
  }

  // ===========================================================================
  // 4. PLUGINS & ADDITIONAL CONTROLS
  // ===========================================================================

  /**
   * Set up map plugins (locate, search, clustering, etc.)
   */
  setupPlugins() {
    throw new Error("Subclass must implement setupPlugins()")
  }

  /**
   * Add locate/geolocation control
   */
  addLocateControl() {
    throw new Error("Subclass must implement addLocateControl()")
  }

  /**
   * Add address search control
   */
  addSearchControl() {
    throw new Error("Subclass must implement addSearchControl()")
  }

  /**
   * Set up marker clustering
   */
  setupClustering() {
    throw new Error("Subclass must implement setupClustering()")
  }

  // ===========================================================================
  // 5. FEATURE RENDERING
  // ===========================================================================

  /**
   * Add GeoJSON features to the map
   * @param {Object} features - GeoJSON FeatureCollection
   * @param {Object} options - Rendering options
   * @param {Boolean} options.editable - Whether features are editable
   */
  addFeatures(features, options = {}) {
    throw new Error("Subclass must implement addFeatures()")
  }

  /**
   * Add admin-defined features as a read-only overlay
   * @param {Object} features - GeoJSON FeatureCollection
   */
  addAdminFeatures(features) {
    throw new Error("Subclass must implement addAdminFeatures()")
  }

  /**
   * Render the admin features explanation note
   */
  renderAdminFeaturesNote() {
    throw new Error("Subclass must implement renderAdminFeaturesNote()")
  }

  /**
   * Create a marker with custom icon
   * @param {Object} latlng - { lat, lng }
   * @param {Object} options - Marker options (color, icon name)
   */
  createMarker(latlng, options = {}) {
    throw new Error("Subclass must implement createMarker()")
  }

  /**
   * Open popup for a feature (AJAX load content)
   * @param {Object} feature - The clicked feature
   */
  openFeaturePopup(feature) {
    throw new Error("Subclass must implement openFeaturePopup()")
  }

  // ===========================================================================
  // 6. EDITING CONTROLS
  // ===========================================================================

  /**
   * Enable editing mode and add drawing controls
   * @param {Object} options - Editing options
   * @param {Boolean} options.enableShapes - Allow drawing shapes (not just markers)
   * @param {Boolean} options.adminEditor - Admin editing mode
   * @param {Number} options.featuresLimit - Max number of features allowed
   */
  enableEditing(options = {}) {
    throw new Error("Subclass must implement enableEditing()")
  }

  /**
   * Set up drawing/editing toolbar
   * @param {Object} options
   */
  setupEditingControls(options) {
    throw new Error("Subclass must implement setupEditingControls()")
  }

  /**
   * Add clear/reset map control
   */
  addClearMapControl() {
    throw new Error("Subclass must implement addClearMapControl()")
  }

  /**
   * Add set center control (for precise positioning of map center)
   * When active, clicking on the map sets the center coordinates
   */
  addSetCenterControl() {
    // Optional - subclasses can implement if needed
  }

  /**
   * Set up event listeners for editable features (click to edit, etc.)
   * @param {Object} layer - The feature layer
   */
  setupEditableFeatureListeners(layer) {
    throw new Error("Subclass must implement setupEditableFeatureListeners()")
  }

  /**
   * Handle newly created features
   * @param {Object} event - The create event
   */
  onFeatureCreated(event) {
    throw new Error("Subclass must implement onFeatureCreated()")
  }

  /**
   * Set feature styling for next created features.
   * Called when the user selects labels/sentiments that affect pin appearance.
   * @param {String|null} color - Hex color for the feature
   * @param {String|null} iconName - Font Awesome icon name
   * @param {String|null} iconUnicode - Font Awesome unicode value
   * @param {String|null} categoryName - Category/label name
   */
  setFeatureStyle(color, iconName, iconUnicode, categoryName) {
    // Subclasses implement to update drawing tool styling
  }

  // ===========================================================================
  // 7. FORM INPUT SYNCHRONIZATION
  // ===========================================================================

  /**
   * Set up event listeners for map changes that update form inputs
   * @param {Object} callbacks
   * @param {Function} callbacks.onMove - Called when map center changes
   * @param {Function} callbacks.onZoom - Called when zoom changes
   * @param {Function} callbacks.onCreate - Called when feature is created
   * @param {Function} callbacks.onEdit - Called when feature is edited
   * @param {Function} callbacks.onClear - Called when features are cleared
   */
  onMapChange(callbacks) {
    this.callbacks = callbacks
  }

  /**
   * Get all editable features as GeoJSON FeatureCollection
   * @returns {Object} GeoJSON FeatureCollection
   */
  getEditableFeatures() {
    throw new Error("Subclass must implement getEditableFeatures()")
  }

  /**
   * Clear all editable features from the map
   */
  clearEditableFeatures() {
    throw new Error("Subclass must implement clearEditableFeatures()")
  }

  // ===========================================================================
  // 8. MAP STATE GETTERS/SETTERS
  // ===========================================================================

  /**
   * Get the current center of the map
   * @returns {Object} { lat, lng }
   */
  getCenter() {
    throw new Error("Subclass must implement getCenter()")
  }

  /**
   * Get the current zoom level
   * @returns {Number}
   */
  getZoom() {
    throw new Error("Subclass must implement getZoom()")
  }

  /**
   * Get the current altitude (for 3D maps)
   * @returns {Number}
   */
  getAltitude() {
    return 0
  }

  /**
   * Set the map view
   * @param {Number} lat
   * @param {Number} lng
   * @param {Number} zoom
   */
  setView(lat, lng, zoom) {
    throw new Error("Subclass must implement setView()")
  }

  // ===========================================================================
  // 9. UI/UX HELPERS
  // ===========================================================================

  /**
   * Show hint about feature limit
   * @param {Number} limit - Maximum number of features
   */
  showFeatureLimitHint(limit) {
    throw new Error("Subclass must implement showFeatureLimitHint()")
  }

  /**
   * Get default feature color based on context
   * @param {Boolean} isAdmin - Whether in admin context
   * @returns {String} Hex color
   */
  getDefaultFeatureColor(isAdmin = false) {
    return isAdmin ? "#ff0000" : "#3b82f6"
  }

  /**
   * Invalidate map size (call after container resize)
   */
  invalidateSize() {
    throw new Error("Subclass must implement invalidateSize()")
  }
}

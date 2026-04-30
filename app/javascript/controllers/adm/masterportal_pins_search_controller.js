import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "feedback", "clear"]

  static values = {
    feedbackTemplate: String,
    feedbackToken: String,
    feedbackEmpty: String
  }

  connect() {
    this.allLayers = null
    this.debounceTimerId = null
    this.retryCount = 0
  }

  disconnect() {
    if (this.debounceTimerId !== null) {
      window.clearTimeout(this.debounceTimerId)
    }
  }

  search() {
    if (this.debounceTimerId !== null) {
      window.clearTimeout(this.debounceTimerId)
    }

    this.debounceTimerId = window.setTimeout(() => this.runSearch(), 120)
  }

  clear() {
    this.inputTarget.value = ""
    this.runSearch()
    this.inputTarget.focus()
  }

  runSearch() {
    const adapter = this.findAdapter()
    if (!adapter || !adapter.clusterGroup) {
      this.scheduleRetry()
      return
    }

    if (!this.allLayers) {
      const layers = adapter.clusterGroup.getLayers()
      if (layers.length === 0) {
        this.scheduleRetry()
        return
      }
      this.allLayers = layers.slice()
    }

    this.retryCount = 0

    const query = this.inputTarget.value.trim().toLowerCase()
    const matched = query.length === 0
      ? this.allLayers
      : this.allLayers.filter((layer) => this.layerMatches(layer, query))

    adapter.clusterGroup.clearLayers()
    adapter.clusterGroup.addLayers(matched)

    this.updateFeedback(matched.length, query)
    this.toggleClear(query)
  }

  scheduleRetry() {
    if (this.retryCount >= 40) return

    this.retryCount += 1
    window.setTimeout(() => this.runSearch(), 150)
  }

  findAdapter() {
    const container = this.element.querySelector('[data-map-target="container"]')
    return container ? container._mapAdapter : null
  }

  layerMatches(layer, query) {
    const feature = layer.options && layer.options.feature
    if (!feature || !feature.properties) return false

    const searchText = (feature.properties.search_text || "").toString()
    return searchText.includes(query)
  }

  updateFeedback(count, query) {
    if (!this.hasFeedbackTarget) return

    if (query.length === 0) {
      this.feedbackTarget.textContent = ""
      return
    }

    if (count === 0) {
      this.feedbackTarget.textContent = this.feedbackEmptyValue
      return
    }

    this.feedbackTarget.textContent = this.feedbackTemplateValue
      .replace(this.feedbackTokenValue, String(count))
  }

  toggleClear(query) {
    if (!this.hasClearTarget) return

    this.clearTarget.hidden = query.length === 0
  }
}

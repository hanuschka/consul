import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["protocol", "wmsGroup", "geojsonGroup", "choroplethToggle", "choroplethFields"]

  connect() {
    this.toggle()
  }

  protocolChanged() {
    this.toggle()
  }

  choroplethChanged() {
    this.toggleChoropleth()
  }

  toggle() {
    const isGeojson = this.hasProtocolTarget && this.protocolTarget.value === "geojson"

    if (this.hasWmsGroupTarget) {
      this.wmsGroupTarget.classList.toggle("d-none", isGeojson)
    }

    if (this.hasGeojsonGroupTarget) {
      this.geojsonGroupTarget.classList.toggle("d-none", !isGeojson)
    }

    this.toggleChoropleth()
  }

  toggleChoropleth() {
    if (!this.hasChoroplethFieldsTarget) return

    const enabled = this.hasChoroplethToggleTarget && this.choroplethToggleTarget.checked
    this.choroplethFieldsTarget.classList.toggle("d-none", !enabled)
  }
}

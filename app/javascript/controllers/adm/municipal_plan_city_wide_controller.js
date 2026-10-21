import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["cityWide", "district", "mapField"]

  connect() {
    this.updateMapField()
  }

  cityWideChanged() {
    if (this.cityWideTarget.checked) {
      this.districtTargets.forEach((checkbox) => { checkbox.checked = false })
    }

    this.updateMapField()
  }

  districtChanged(event) {
    if (!event.target.checked || !this.hasCityWideTarget) return

    this.cityWideTarget.checked = false
    this.updateMapField()
  }

  updateMapField() {
    if (!this.hasCityWideTarget || !this.hasMapFieldTarget) return

    this.mapFieldTarget.hidden = this.cityWideTarget.checked
  }
}

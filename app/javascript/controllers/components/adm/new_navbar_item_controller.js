import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "presets", "projekts", "external", "customTitle" ]

  kindChanged(event) {
    const targets = {
      presets: this.presetsTarget,
      projekts: this.projektsTarget,
      external: this.externalTarget
    }

    Object.values(targets).forEach(target => target.style.display = "none")
    targets[event.target.value].style.display = "block"

    if (this.hasCustomTitleTarget) {
      this.customTitleTarget.style.display = event.target.value === "external" ? "none" : "block"
    }
  }
}

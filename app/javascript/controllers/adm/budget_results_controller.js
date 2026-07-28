import { Controller } from "@hotwired/stimulus"

// Adm counterpart of the frontend ".js-toggle-link" behaviour on the budget
// results page: shows/hides discarded investments (rows and the incompatible
// table, both marked ".js-discarded") and swaps the toggle button label.
export default class extends Controller {
  static targets = ["toggleLabel"]
  static values = {
    showLabel: String,
    hideLabel: String
  }

  toggle() {
    this.discardedVisible = !this.discardedVisible

    this.discardedElements.forEach((element) => {
      element.style.display = this.discardedVisible ? "" : "none"
    })

    this.toggleLabelTarget.textContent =
      this.discardedVisible ? this.hideLabelValue : this.showLabelValue
  }

  get discardedElements() {
    return this.element.querySelectorAll(".js-discarded")
  }
}

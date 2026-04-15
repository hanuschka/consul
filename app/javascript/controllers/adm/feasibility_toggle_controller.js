import { Controller } from "@hotwired/stimulus"

// Toggles visibility of valuator_explanation and valuation_finished
// based on the selected feasibility radio value.
// Hidden when "undecided", visible for "feasible" and "unfeasible".
export default class extends Controller {
  static targets = ["fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.element.querySelector("input[type=radio][name*='feasibility']:checked")
    const value = selected ? selected.value : "undecided"
    const show = value !== "undecided"

    this.fieldsTargets.forEach(el => {
      el.style.display = show ? "" : "none"
    })
  }
}

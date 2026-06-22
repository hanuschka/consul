import { Controller } from "@hotwired/stimulus"

// Generic show/hide driven by a checkbox or radio group.
// "shown" targets are visible when the source is active,
// "hidden" targets when it is not. For radios, active means
// the checked value is listed in the space-separated
// show-for value.
export default class extends Controller {
  static targets = ["source", "shown", "hidden"]
  static values = { showFor: { type: String, default: "" } }

  connect() {
    this.toggle()
  }

  toggle() {
    const active = this.active()

    this.shownTargets.forEach((element) => {
      element.style.display = active ? "" : "none"
    })
    this.hiddenTargets.forEach((element) => {
      element.style.display = active ? "none" : ""
    })
  }

  active() {
    const inputs = this.sourceInputs()
    if (inputs.length === 0) return false

    const checkbox = inputs.find((input) => input.type === "checkbox")
    if (checkbox) return checkbox.checked

    const checked = inputs.find((input) => input.checked)
    if (!checked) return false

    return this.showForValues().includes(checked.value)
  }

  sourceInputs() {
    const elements = this.sourceTargets.length > 0 ? this.sourceTargets : [this.element]

    return elements.flatMap((element) => {
      if (element.matches("input")) return [element]

      return Array.from(element.querySelectorAll("input[type=radio], input[type=checkbox]"))
    })
  }

  showForValues() {
    return this.showForValue.split(" ").filter((value) => value.length > 0)
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "submit"]

  connect() {
    this.update()
  }

  update() {
    this.submitTarget.disabled = this.textareaTarget.value.trim().length === 0
  }

  submitOnModifierEnter(event) {
    if (event.key !== "Enter" || !(event.metaKey || event.ctrlKey)) return
    if (this.submitTarget.disabled) return

    event.preventDefault()
    this.element.requestSubmit()
  }
}

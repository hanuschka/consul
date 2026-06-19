import { Controller } from "@hotwired/stimulus"

// Submits the form on control changes so a "live" filter bar needs no submit
// button. Selects/date fire `change` (immediate); text inputs fire `input`
// (debounced) so typing filters without waiting for blur. Pair with
// `data-turbo-permanent` on the text input to keep focus across the visit.
export default class extends Controller {
  static values = { delay: { type: Number, default: 400 } }

  submit() {
    this.cancelPending()
    this.element.requestSubmit()
  }

  debouncedSubmit() {
    this.cancelPending()
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  cancelPending() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  disconnect() {
    this.cancelPending()
  }
}

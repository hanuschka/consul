import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 1000 },
    fadeDuration: { type: Number, default: 500 }
  }

  connect() {
    setTimeout(() => {
      this.element.style.opacity = '0'
      setTimeout(() => this.element.remove(), this.fadeDurationValue)
    }, this.delayValue)
  }
}

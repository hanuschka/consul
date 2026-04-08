import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "content"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.triggerTargets.forEach((trigger, index) => {
      const content = this.contentTargets[index]
      if (content) {
        content.style.display = trigger.checked ? "block" : "none"
      }
    })
  }
}

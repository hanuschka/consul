import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["trigger", "content"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.contentTarget.style.display = this.triggerTarget.checked ? "block" : "none"
  }
}

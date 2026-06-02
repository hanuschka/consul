import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["row", "body"]

  toggle(event) {
    if (event.target.closest(".adm-ai-question-item--kebab-wrap")) return

    event.preventDefault()
    this.element.classList.toggle("is-open")
  }
}

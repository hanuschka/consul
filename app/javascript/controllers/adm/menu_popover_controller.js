import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "button"]

  connect() {
    this.handleOutsideClick = this.handleOutsideClick.bind(this)
    this.handleEscape = this.handleEscape.bind(this)

    document.addEventListener("click", this.handleOutsideClick)
    document.addEventListener("keydown", this.handleEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.handleOutsideClick)
    document.removeEventListener("keydown", this.handleEscape)
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    this.syncExpanded(this.menuTarget.classList.toggle("is-open"))
  }

  close() {
    this.menuTarget.classList.remove("is-open")
    this.syncExpanded(false)
  }

  syncExpanded(open) {
    if (!this.hasButtonTarget) return

    this.buttonTarget.setAttribute("aria-expanded", open ? "true" : "false")
  }

  handleOutsideClick(event) {
    if (this.element.contains(event.target)) return

    this.close()
  }

  handleEscape(event) {
    if (event.key !== "Escape") return

    this.close()
  }
}

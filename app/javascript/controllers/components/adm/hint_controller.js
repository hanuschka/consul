import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.isOpen = false
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.panelTarget.classList.add("adm-hint__panel--open")
    this.panelTarget.setAttribute("aria-hidden", "false")
    this.element.querySelector(".adm-hint__toggle").setAttribute("aria-expanded", "true")
    this.isOpen = true
  }

  close() {
    this.panelTarget.classList.remove("adm-hint__panel--open")
    this.panelTarget.setAttribute("aria-hidden", "true")
    this.element.querySelector(".adm-hint__toggle").setAttribute("aria-expanded", "false")
    this.isOpen = false
  }
}

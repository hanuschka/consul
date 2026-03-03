import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar"]

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
    this.sidebarTarget.classList.add("adm-hint__sidebar--open")
    this.sidebarTarget.setAttribute("aria-hidden", "false")
    this.element.querySelector(".adm-hint__toggle").setAttribute("aria-expanded", "true")
    this.isOpen = true
  }

  close() {
    this.sidebarTarget.classList.remove("adm-hint__sidebar--open")
    this.sidebarTarget.setAttribute("aria-hidden", "true")
    this.element.querySelector(".adm-hint__toggle").setAttribute("aria-expanded", "false")
    this.isOpen = false
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.handleClick)
    this.element.addEventListener("keydown", this.handleKeydown)
    document.addEventListener("click", this.handleOutsideClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
    this.element.removeEventListener("keydown", this.handleKeydown)
    document.removeEventListener("click", this.handleOutsideClick)
  }

  handleClick = (event) => {
    const toggle = event.target.closest(".js-dropdown-select-menu-toggle")

    if (toggle) {
      event.preventDefault()
      this.toggleContainer(toggle.closest(".dropdown-select-container"))
      return
    }

    if (event.target.closest(".js-dropdown-select-menu-item")) {
      this.closeAll()
    }
  }

  handleKeydown = (event) => {
    if (event.key !== "Escape") return

    this.closeAll()
  }

  handleOutsideClick = (event) => {
    if (event.target.closest(".dropdown-select-container")) return

    this.closeAll()
  }

  toggleContainer(container) {
    if (!container) return

    const isOpen = container.classList.toggle("dropdown-open")
    const toggle = container.querySelector(".js-dropdown-select-menu-toggle")

    if (toggle) toggle.setAttribute("aria-expanded", String(isOpen))
  }

  closeAll() {
    const containers = this.element.querySelectorAll(".dropdown-select-container.dropdown-open")

    containers.forEach((container) => {
      container.classList.remove("dropdown-open")
      const toggle = container.querySelector(".js-dropdown-select-menu-toggle")

      if (toggle) toggle.setAttribute("aria-expanded", "false")
    })
  }
}

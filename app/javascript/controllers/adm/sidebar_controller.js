import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggler", "sidebar" ]

  connect() {
    this.sidebarHidden = true
    this.togglerTarget.addEventListener("click", () => { this.toggle() })
    this.togglerTarget.addEventListener("keypress", (event) => {
      event.preventDefault();
      if (event.key === "Enter" || event.key === " ") {
        this.toggle()
      }
    })
  }

  toggle() {
    if (this.sidebarHidden) {
      this.showSidebar()
    } else {
      this.hideSidebar()
    }
  }

  showSidebar() {
    this.sidebarTarget.classList.remove("d-none")
    this.togglerTarget.classList.add("adm-sidebar-toggle--open")
    this.togglerTarget.querySelector("span").textContent = "close"
    this.togglerTarget.setAttribute("aria-expanded", "true")
    document.body.style.overflow = "hidden"
    this.sidebarHidden = false
  }

  hideSidebar() {
    this.sidebarTarget.classList.add("d-none")
    this.togglerTarget.classList.remove("adm-sidebar-toggle--open")
    this.togglerTarget.querySelector("span").textContent = "menu"
    this.togglerTarget.setAttribute("aria-expanded", "false")
    document.body.style.overflow = ""
    this.sidebarHidden = true
  }
}

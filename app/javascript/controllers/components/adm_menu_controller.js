import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "expandable" ]

  connect() {
    this.expandableTargets.forEach((element) => {
      this.restoreState(element)
      element.addEventListener("click", this.toggleExpanded.bind(this))
      element.addEventListener("keypress", (event) => {
        event.preventDefault();
        if (event.key === "Enter" || event.key === " ") {
          this.toggleExpanded(event)
        }
      })
    })
  }

  toggleExpanded(event) {
    event.preventDefault()
    event.currentTarget.classList.toggle("expanded")
    const isExpanded = event.currentTarget.classList.contains("expanded")
    event.currentTarget.setAttribute("aria-expanded", isExpanded)
    this.saveState(event.currentTarget, isExpanded)
  }

  restoreState(element) {
    const key = this.storageKey(element)
    if (!key) return

    const saved = sessionStorage.getItem(key)
    if (saved === null) return

    if (saved === "true") {
      element.classList.add("expanded")
      element.setAttribute("aria-expanded", "true")
    } else {
      element.classList.remove("expanded")
      element.setAttribute("aria-expanded", "false")
    }
  }

  saveState(element, isExpanded) {
    const key = this.storageKey(element)
    if (key) sessionStorage.setItem(key, isExpanded)
  }

  storageKey(element) {
    const menuId = element.dataset.admMenuId
    return menuId ? `adm-menu-expanded-${menuId}` : null
  }
}

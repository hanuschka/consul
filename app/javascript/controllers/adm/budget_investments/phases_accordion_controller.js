import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.onToggle = this.onToggle.bind(this)
    this.element.addEventListener("toggle", this.onToggle, true)
  }

  disconnect() {
    this.element.removeEventListener("toggle", this.onToggle, true)
  }

  onToggle(event) {
    const target = event.target
    if (!(target instanceof HTMLDetailsElement)) return
    if (!target.classList.contains("adm-admin-phase")) return
    if (!target.open) return

    this.element.querySelectorAll("details.adm-admin-phase[open]").forEach(el => {
      if (el !== target) el.open = false
    })
  }
}

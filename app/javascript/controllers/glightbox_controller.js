import { Controller } from "@hotwired/stimulus"
import GLightbox from "glightbox"

let instanceCounter = 0

export default class extends Controller {
  connect() {
    instanceCounter += 1
    this.scopeClass = `glightbox-instance-${instanceCounter}`
    this.element.classList.add(this.scopeClass)

    this.lightbox = GLightbox({
      selector: `.${this.scopeClass}`,
      touchNavigation: true,
      loop: false,
      zoomable: true,
      draggable: true,
      openEffect: "fade",
      closeEffect: "fade",
      slideEffect: "fade"
    })
  }

  disconnect() {
    if (this.lightbox) {
      this.lightbox.destroy()
      this.lightbox = null
    }

    if (this.scopeClass) {
      this.element.classList.remove(this.scopeClass)
      this.scopeClass = null
    }
  }
}

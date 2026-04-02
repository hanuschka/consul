import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iframe"]

  connect() {
    this.resizeHandler = () => this.setFullHeight()
    window.addEventListener("resize", this.resizeHandler)
  }

  disconnect() {
    window.removeEventListener("resize", this.resizeHandler)
  }

  loaded() {
    this.iframeTarget.classList.add("-loaded")
    this.setFullHeight()
  }

  setFullHeight() {
    const top = this.iframeTarget.getBoundingClientRect().top
    this.iframeTarget.style.height = `calc(100dvh - ${top}px)`
  }
}

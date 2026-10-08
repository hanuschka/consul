import { Controller } from "@hotwired/stimulus"

const MAX_HEIGHT = 200000

export default class extends Controller {
  static targets = ["frame"]
  static values = { origin: String }

  connect() {
    this.loads = 0
    this.receive = this.receive.bind(this)
    window.addEventListener("message", this.receive)
  }

  disconnect() {
    window.removeEventListener("message", this.receive)
  }

  loaded() {
    this.loads += 1
    if (this.loads > 1) window.scrollTo({ top: 0 })
  }

  receive(event) {
    if (!this.originValue || event.origin !== this.originValue) return
    if (event.source !== this.frameTarget.contentWindow) return

    const data = event.data || {}
    if (data.type === "dt-handbook:height") this.resize(data.height)
    else if (data.type === "dt-handbook:scroll") this.scrollToOffset(data.top)
  }

  resize(height) {
    const value = Math.ceil(Number(height))
    if (!Number.isFinite(value) || value <= 0 || value > MAX_HEIGHT) return

    this.frameTarget.style.height = `${value}px`
  }

  scrollToOffset(top) {
    const value = Number(top)
    if (!Number.isFinite(value)) return

    const frameTop = this.frameTarget.getBoundingClientRect().top + window.scrollY
    window.scrollTo({ top: Math.max(0, frameTop + value - this.stickyHeaderHeight()) })
  }

  stickyHeaderHeight() {
    const header = document.querySelector(".adm-header")
    if (!header || getComputedStyle(header).position !== "sticky") return 0

    return header.offsetHeight
  }
}

import { Controller } from "@hotwired/stimulus"

// Scrolls to and briefly blinks a blue background on the element targeted by
// the URL anchor, so a deep link to a specific /adm field lands on it and
// draws the eye on arrival. The scroll is deferred past Turbo's own scroll
// restoration and past late layout shifts (web font loading), both of which
// would otherwise land it at the wrong position.
export default class extends Controller {
  connect() {
    this.scheduleRun = this.scheduleRun.bind(this)
    document.addEventListener("turbo:load", this.scheduleRun)
    window.addEventListener("hashchange", this.scheduleRun)
    this.scheduleRun()
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.scheduleRun)
    window.removeEventListener("hashchange", this.scheduleRun)
    clearTimeout(this.timer)
  }

  scheduleRun() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.runWhenReady(), 80)
  }

  runWhenReady() {
    if (document.fonts && document.fonts.ready) {
      document.fonts.ready.then(() => this.run())
    } else {
      this.run()
    }
  }

  run() {
    const hash = window.location.hash
    if (hash.length < 2) return

    const target = document.getElementById(decodeURIComponent(hash.slice(1)))
    if (!target) return

    const element = this.elementToHighlight(target)
    element.scrollIntoView({ behavior: "instant", block: "center" })
    this.blink(element)
  }

  blink(element) {
    element.classList.remove("adm-anchor-highlight")
    void element.offsetWidth
    element.classList.add("adm-anchor-highlight")

    element.addEventListener(
      "animationend",
      () => element.classList.remove("adm-anchor-highlight"),
      { once: true }
    )
  }

  elementToHighlight(target) {
    if (target.tagName === "TURBO-FRAME" && target.firstElementChild) {
      return target.firstElementChild
    }

    return target
  }
}

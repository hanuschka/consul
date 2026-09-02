import { Controller } from "@hotwired/stimulus"

// Floating "back to the top" control for pages long enough to lose their header.
//
// Stays out of the way until the page is scrolled past the threshold, so a short
// page never carries a control with nowhere to go. The jump is instant on
// purpose: the page-wide `scroll-behavior: smooth` would otherwise animate a
// screen-height-times-hundred scroll the reader has to wait out.
//
// HTML hook:
//   <button data-controller="shared--scroll-to-top"
//           data-action="click->shared--scroll-to-top#scroll"
//           data-shared--scroll-to-top-threshold-value="600">   (optional)
export default class extends Controller {
  static values = { threshold: { type: Number, default: 400 } }

  connect() {
    this.onScroll = this.toggle.bind(this)
    window.addEventListener("scroll", this.onScroll, { passive: true })

    this.toggle()
  }

  disconnect() {
    window.removeEventListener("scroll", this.onScroll)
  }

  toggle() {
    this.element.classList.toggle("-visible", window.scrollY > this.thresholdValue)
  }

  scroll() {
    window.scrollTo({ top: 0, behavior: "instant" })
  }
}

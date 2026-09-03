import { Controller } from "@hotwired/stimulus"

// Fetches the duplicate set once, on the first hover or focus, and keeps the
// markup for every later open: the table renders one badge per row, so
// rendering the sets with the page would load every peer and its image.
export default class extends Controller {
  static targets = ["popup"]
  static values = { url: String }

  connect() {
    this.loaded = false
    this.loading = false
  }

  open() {
    if (!this.hasPopupTarget) return

    this.popupTarget.hidden = false
    this.position()
    this.load()
  }

  // The panel is fixed, so it is placed from the badge's viewport rect and
  // flipped above the badge when it would run past the bottom edge.
  position() {
    const badge = this.element.getBoundingClientRect()
    const popup = this.popupTarget
    const gap = 8

    popup.style.left = `${Math.max(gap, Math.min(badge.left, window.innerWidth - popup.offsetWidth - gap))}px`

    const spaceBelow = window.innerHeight - badge.bottom

    if (spaceBelow < popup.offsetHeight + gap && badge.top > popup.offsetHeight + gap) {
      popup.style.top = `${badge.top - popup.offsetHeight - gap}px`
    } else {
      popup.style.top = `${badge.bottom + gap}px`
    }
  }

  close() {
    if (!this.hasPopupTarget) return

    this.popupTarget.hidden = true
  }

  async load() {
    if (this.loaded || this.loading || !this.urlValue) return

    this.loading = true
    this.popupTarget.classList.add("is-loading")

    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "text/html", "X-Requested-With": "XMLHttpRequest" }
      })

      if (!response.ok) throw new Error(`Request failed with ${response.status}`)

      this.popupTarget.innerHTML = await response.text()
      this.loaded = true
      this.position()
    } catch (error) {
      console.error("[SimilarContributionsPopup]", error)
      this.popupTarget.hidden = true
    } finally {
      this.loading = false
      this.popupTarget.classList.remove("is-loading")
    }
  }
}

import { Controller } from "@hotwired/stimulus"

const CLOSE_DELAY = 250

// Fetches the duplicate set once, on the first hover or focus, and keeps the
// markup for every later open: the table renders one badge per row, so
// rendering the sets with the page would load every peer and its image.
export default class extends Controller {
  static targets = ["popup"]
  static values = { url: String }

  connect() {
    this.loaded = false
    this.loading = false
    this.closeTimeout = null
  }

  disconnect() {
    this.cancelClose()
  }

  open() {
    if (!this.hasPopupTarget) return

    this.cancelClose()
    this.popupTarget.hidden = false
    this.position()
    this.load()
  }

  // The panel is fixed, so it is placed from the viewport rect of the cell it
  // belongs to: its right edge meets the cell's, and it flips above the badge
  // when it would run past the bottom edge.
  position() {
    const badge = this.element.getBoundingClientRect()
    const anchor = (this.element.closest("th, td") || this.element).getBoundingClientRect()
    const popup = this.popupTarget
    const gap = 8

    const right = Math.min(anchor.right, window.innerWidth - gap)
    popup.style.left = `${Math.max(gap, right - popup.offsetWidth)}px`

    const spaceBelow = window.innerHeight - badge.bottom

    if (spaceBelow < popup.offsetHeight + gap && badge.top > popup.offsetHeight + gap) {
      popup.style.top = `${badge.top - popup.offsetHeight - gap}px`
    } else {
      popup.style.top = `${badge.bottom + gap}px`
    }
  }

  // The gap between the badge and the panel is outside both, so the pointer
  // leaves the wrapper on its way into the panel: the panel only goes away
  // once the pointer has stayed out for the grace period, which is what makes
  // its links and its scrollbar reachable with the mouse.
  close() {
    if (!this.hasPopupTarget) return

    this.cancelClose()
    this.closeTimeout = window.setTimeout(() => {
      this.closeTimeout = null

      if (this.element.contains(document.activeElement)) return

      this.popupTarget.hidden = true
    }, CLOSE_DELAY)
  }

  cancelClose() {
    if (this.closeTimeout === null) return

    window.clearTimeout(this.closeTimeout)
    this.closeTimeout = null
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

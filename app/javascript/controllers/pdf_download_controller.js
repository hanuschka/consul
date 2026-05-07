import { Controller } from "@hotwired/stimulus"

const RESTORE_AFTER_NAV_MS = 800
const FALLBACK_RESTORE_MS = 8000
const COMPLETE_EVENT = "pdf-download:complete"

export default class extends Controller {
  static targets = ["trigger", "loading"]

  connect() {
    this.handleComplete = () => this.restore()
    this.element.addEventListener(COMPLETE_EVENT, this.handleComplete)
  }

  disconnect() {
    this.element.removeEventListener(COMPLETE_EVENT, this.handleComplete)
    this.clearRestoreTimer()
  }

  begin(event) {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.triggerTarget.setAttribute("aria-disabled", "true")
    this.triggerTarget.setAttribute("tabindex", "-1")
    this.loadingTarget.classList.add("-active")
    this.loadingTarget.removeAttribute("aria-hidden")

    const delay = this.expectsAsyncCapture(event) ? FALLBACK_RESTORE_MS : RESTORE_AFTER_NAV_MS

    this.clearRestoreTimer()
    this.restoreTimer = setTimeout(() => this.restore(), delay)
  }

  restore() {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.triggerTarget.removeAttribute("aria-disabled")
    this.triggerTarget.removeAttribute("tabindex")
    this.loadingTarget.classList.remove("-active")
    this.loadingTarget.setAttribute("aria-hidden", "true")
    this.clearRestoreTimer()
  }

  expectsAsyncCapture(event) {
    const link = event && event.currentTarget
    if (!link || !link.dataset || !link.dataset.action) return false

    return link.dataset.action.includes("map-screenshot#capture")
  }

  clearRestoreTimer() {
    if (this.restoreTimer) {
      clearTimeout(this.restoreTimer)
      this.restoreTimer = null
    }
  }
}

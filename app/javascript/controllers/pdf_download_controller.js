import { Controller } from "@hotwired/stimulus"

const SUCCESS_AFTER_NAV_MS = 800
const FALLBACK_SUCCESS_MS = 8000
const SUCCESS_VISIBLE_MS = 1800
const COMPLETE_EVENT = "pdf-download:complete"

export default class extends Controller {
  static targets = ["trigger", "loading", "success"]

  connect() {
    this.handleComplete = () => this.showSuccess()
    this.element.addEventListener(COMPLETE_EVENT, this.handleComplete)
  }

  disconnect() {
    this.element.removeEventListener(COMPLETE_EVENT, this.handleComplete)
    this.clearSuccessTimer()
    this.clearRestoreTimer()
  }

  begin(event) {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.triggerTarget.setAttribute("aria-disabled", "true")
    this.triggerTarget.setAttribute("tabindex", "-1")
    this.loadingTarget.classList.add("-active")
    this.loadingTarget.removeAttribute("aria-hidden")

    if (this.hasSuccessTarget) {
      this.successTarget.classList.remove("-active")
      this.successTarget.setAttribute("aria-hidden", "true")
    }

    const delay = this.expectsAsyncCapture(event) ? FALLBACK_SUCCESS_MS : SUCCESS_AFTER_NAV_MS

    this.clearSuccessTimer()
    this.successTimer = setTimeout(() => this.showSuccess(), delay)
  }

  showSuccess() {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.clearSuccessTimer()
    this.loadingTarget.classList.remove("-active")
    this.loadingTarget.setAttribute("aria-hidden", "true")

    if (this.hasSuccessTarget) {
      this.successTarget.classList.add("-active")
      this.successTarget.removeAttribute("aria-hidden")
    }

    this.clearRestoreTimer()
    this.restoreTimer = setTimeout(() => this.restore(), SUCCESS_VISIBLE_MS)
  }

  restore() {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.triggerTarget.removeAttribute("aria-disabled")
    this.triggerTarget.removeAttribute("tabindex")
    this.loadingTarget.classList.remove("-active")
    this.loadingTarget.setAttribute("aria-hidden", "true")

    if (this.hasSuccessTarget) {
      this.successTarget.classList.remove("-active")
      this.successTarget.setAttribute("aria-hidden", "true")
    }

    this.clearSuccessTimer()
    this.clearRestoreTimer()
  }

  expectsAsyncCapture(event) {
    const link = event && event.currentTarget
    if (!link || !link.dataset || !link.dataset.action) return false

    return link.dataset.action.includes("map-screenshot#capture")
  }

  clearSuccessTimer() {
    if (this.successTimer) {
      clearTimeout(this.successTimer)
      this.successTimer = null
    }
  }

  clearRestoreTimer() {
    if (this.restoreTimer) {
      clearTimeout(this.restoreTimer)
      this.restoreTimer = null
    }
  }
}

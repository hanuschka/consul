import { Controller } from "@hotwired/stimulus"

const BEGIN_EVENT = "adm-button-with-progress:begin"
const COMPLETE_EVENT = "adm-button-with-progress:complete"
const RESTORE_EVENT = "adm-button-with-progress:restore"
const SUCCESS_VISIBLE_MS = 1800

export default class extends Controller {
  static targets = ["trigger", "loading", "success"]
  static values = {
    fallbackDelay: { type: Number, default: 0 }
  }

  connect() {
    this.handleBegin = () => this.begin()
    this.handleComplete = () => this.succeed()
    this.handleRestore = () => this.restore()
    this.element.addEventListener(BEGIN_EVENT, this.handleBegin)
    this.element.addEventListener(COMPLETE_EVENT, this.handleComplete)
    this.element.addEventListener(RESTORE_EVENT, this.handleRestore)
  }

  disconnect() {
    this.element.removeEventListener(BEGIN_EVENT, this.handleBegin)
    this.element.removeEventListener(COMPLETE_EVENT, this.handleComplete)
    this.element.removeEventListener(RESTORE_EVENT, this.handleRestore)
    this.clearFallbackTimer()
    this.clearRestoreTimer()
  }

  begin() {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.triggerTarget.setAttribute("aria-disabled", "true")
    this.triggerTarget.setAttribute("tabindex", "-1")
    this.loadingTarget.classList.add("-active")
    this.loadingTarget.removeAttribute("aria-hidden")

    if (this.hasSuccessTarget) {
      this.successTarget.classList.remove("-active")
      this.successTarget.setAttribute("aria-hidden", "true")
    }

    this.clearFallbackTimer()

    if (this.fallbackDelayValue > 0) {
      this.fallbackTimer = setTimeout(() => this.succeed(), this.fallbackDelayValue)
    }
  }

  succeed() {
    if (!this.hasTriggerTarget || !this.hasLoadingTarget) return

    this.clearFallbackTimer()
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

    this.clearFallbackTimer()
    this.clearRestoreTimer()
  }

  clearFallbackTimer() {
    if (this.fallbackTimer) {
      clearTimeout(this.fallbackTimer)
      this.fallbackTimer = null
    }
  }

  clearRestoreTimer() {
    if (this.restoreTimer) {
      clearTimeout(this.restoreTimer)
      this.restoreTimer = null
    }
  }
}

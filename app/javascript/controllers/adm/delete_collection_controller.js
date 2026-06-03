import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "trigger", "error", "errorText"]

  static values = {
    deleteUrl: String,
    statusUrl: String,
    confirm: String,
    initialStatus: String,
    pollInterval: { type: Number, default: 3000 }
  }

  connect() {
    this.pollTimerId = null

    if (this.initialStatusValue === "running") {
      this.showProgress()
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  start(event) {
    event.preventDefault()

    if (this.confirmValue && !window.confirm(this.confirmValue)) return

    this.showProgress()
    this.runDelete()
  }

  async runDelete() {
    try {
      const response = await fetch(this.deleteUrlValue, {
        method: "DELETE",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() }
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.startPolling()
    } catch (error) {
      this.showError(error.message)
    }
  }

  startPolling() {
    this.stopPolling()
    this.fetchStatus()
    this.pollTimerId = window.setInterval(() => this.fetchStatus(), this.pollIntervalValue)
  }

  stopPolling() {
    if (this.pollTimerId !== null) {
      window.clearInterval(this.pollTimerId)
      this.pollTimerId = null
    }
  }

  async fetchStatus() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const body = await response.json()
      this.applyStatus(body)
    } catch (error) {
    }
  }

  applyStatus(body) {
    if (body.status === "success") {
      this.stopPolling()
      window.location.reload()
      return
    }

    if (body.status === "failed") {
      this.stopPolling()
      this.showError(body.error)
    }
  }

  showProgress() {
    this.progressTarget.hidden = false
    this.triggerTarget.style.display = "none"

    if (this.hasErrorTarget) this.errorTarget.hidden = true
  }

  showError(message) {
    this.progressTarget.hidden = true
    this.triggerTarget.style.display = ""

    if (this.hasErrorTarget) {
      this.errorTextTarget.textContent = message || ""
      this.errorTarget.hidden = false
    }
  }

  csrfToken() {
    const el = document.querySelector("meta[name='csrf-token']")
    return el ? el.getAttribute("content") : ""
  }
}

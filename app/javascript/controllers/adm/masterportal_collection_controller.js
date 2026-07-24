import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["progress", "error", "errorText", "actions", "diff", "diffIcon", "diffText", "color", "colorSave", "colorSaveIcon"]

  static values = {
    updateUrl: String,
    updateColorUrl: String,
    deleteUrl: String,
    statusUrl: String,
    diffUrl: String,
    cleanUrl: String,
    cardUrl: String,
    confirm: String,
    cleanConfirm: String,
    checkingLabel: String,
    initialImportStatus: String,
    initialDestroyStatus: String,
    pollInterval: { type: Number, default: 3000 }
  }

  connect() {
    this.pollTimerId = null

    if (this.initialDestroyStatusValue === "running") {
      this.mode = "destroy"
      this.showProgress()
      this.startPolling()
    } else if (this.initialImportStatusValue === "running") {
      this.mode = "import"
      this.showProgress()
      this.startPolling()
    }
  }

  disconnect() {
    this.stopPolling()
  }

  importAndClean(event) {
    event.preventDefault()

    this.pendingClean = true
    this.startImport()
  }

  startImport() {
    this.mode = "import"
    this.showProgress()
    this.sendRequest("PATCH", this.updateUrlValue)
  }

  async updateColor() {
    this.colorTarget.disabled = true
    this.colorSaveTarget.disabled = true
    this.colorSaveTarget.classList.add("-saving")
    this.setColorSaveIcon("progress_activity")

    try {
      const response = await fetch(this.updateColorUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        credentials: "same-origin",
        body: JSON.stringify({ feature_color: this.colorTarget.value })
      })
      if (!response.ok) throw new Error(await this.errorMessage(response))

      this.flashColorSaved()
    } catch (error) {
      this.setColorSaveIcon("save")
      this.showError(error.message)
    } finally {
      this.colorTarget.disabled = false
      this.colorSaveTarget.disabled = false
      this.colorSaveTarget.classList.remove("-saving")
    }
  }

  setColorSaveIcon(name) {
    if (this.hasColorSaveIconTarget) this.colorSaveIconTarget.textContent = name
  }

  flashColorSaved() {
    this.setColorSaveIcon("check")
    window.setTimeout(() => this.setColorSaveIcon("save"), 1500)
  }

  remove(event) {
    event.preventDefault()

    if (this.confirmValue && !window.confirm(this.confirmValue)) return

    this.mode = "destroy"
    this.showProgress()
    this.sendRequest("DELETE", this.deleteUrlValue)
  }

  async runCleanThenRefresh() {
    try {
      const response = await this.request("DELETE", this.cleanUrlValue)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.refreshCard()
    } catch (error) {
      this.showError(error.message)
    }
  }

  async kickoffUpdate() {
    this.mode = "import"
    this.showProgress()

    try {
      const response = await this.request("PATCH", this.updateUrlValue)

      return response.ok
    } catch (error) {
      this.showError(error.message)

      return false
    }
  }

  async cleanInPlace() {
    this.mode = "destroy"
    this.showProgress()

    try {
      const response = await this.request("DELETE", this.cleanUrlValue)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      return true
    } catch (error) {
      this.showError(error.message)

      return false
    }
  }

  async resync() {
    this.showChecking()

    try {
      const response = await this.request("GET", this.diffUrlValue)
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      Turbo.renderStreamMessage(await response.text())
    } catch (error) {
      this.showDiffError(error.message)
    }
  }

  async sendRequest(method, url) {
    try {
      const response = await this.request(method, url)
      if (!response.ok) throw new Error(await this.errorMessage(response))

      this.startPolling()
    } catch (error) {
      this.showError(error.message)
    }
  }

  async errorMessage(response) {
    try {
      const body = await response.json()
      if (body && body.message) return body.message
    } catch (error) {
    }

    return `HTTP ${response.status}`
  }

  request(method, url) {
    return fetch(url, {
      method: method,
      headers: { Accept: "text/vnd.turbo-stream.html, application/json", "X-CSRF-Token": this.csrfToken() },
      credentials: "same-origin"
    })
  }

  csrfToken() {
    const el = document.querySelector("meta[name='csrf-token']")

    return el ? el.getAttribute("content") : ""
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
      const response = await this.request("GET", this.statusUrlValue)
      if (!response.ok) return

      const body = await response.json()
      this.applyStatus(body)
    } catch (error) {
    }
  }

  applyStatus(body) {
    if (this.mode === "destroy") {
      this.applyDestroyStatus(body)
      return
    }

    this.applyImportStatus(body)
  }

  applyDestroyStatus(body) {
    if (body.deleted || body.destroy_status === "success") {
      this.stopPolling()
      this.refreshCard()
    } else if (body.destroy_status === "failed") {
      this.stopPolling()
      this.showError(body.destroy_error)
    }
  }

  applyImportStatus(body) {
    if (body.import_status === "success") {
      this.stopPolling()

      if (this.pendingClean) {
        this.pendingClean = false
        this.runCleanThenRefresh()
      } else {
        this.refreshCard()
      }
    } else if (body.import_status === "failed") {
      this.stopPolling()
      this.pendingClean = false
      this.showError(body.import_error)
    }
  }

  async refreshCard() {
    try {
      const response = await this.request("GET", this.cardUrlValue)
      if (!response.ok) return

      Turbo.renderStreamMessage(await response.text())
      this.reloadPinsSummary()
    } catch (error) {
    }
  }

  reloadPinsSummary() {
    const frame = document.querySelector("turbo-frame[id^='masterportal_pins_summary_']")

    if (frame && typeof frame.reload === "function") frame.reload()
  }

  showChecking() {
    if (!this.hasDiffTarget) return

    this.setDiffIcon("progress_activity")
    this.diffTextTarget.textContent = this.checkingLabelValue
    this.diffTarget.dataset.state = "checking"
    this.diffTarget.hidden = false
  }

  showDiffError(message) {
    if (!this.hasDiffTarget) return

    this.setDiffIcon("error")
    this.diffTextTarget.textContent = message || ""
    this.diffTarget.dataset.state = "error"
    this.diffTarget.hidden = false
  }

  setDiffIcon(name) {
    if (this.hasDiffIconTarget) this.diffIconTarget.textContent = name
  }

  showProgress() {
    this.progressTarget.hidden = false

    if (this.hasActionsTarget) this.actionsTarget.hidden = true
    if (this.hasErrorTarget) this.errorTarget.hidden = true
  }

  showError(message) {
    this.progressTarget.hidden = true

    if (this.hasActionsTarget) this.actionsTarget.hidden = false
    if (this.hasErrorTarget) {
      this.errorTextTarget.textContent = message || ""
      this.errorTarget.hidden = false
    }
  }
}

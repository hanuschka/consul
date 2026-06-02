import { Controller } from "@hotwired/stimulus"
import { get, patch, destroy } from "@rails/request.js"

export default class extends Controller {
  static targets = ["progress", "error", "errorText", "actions", "diff", "diffIcon", "diffText", "cleanButton"]

  static values = {
    updateUrl: String,
    deleteUrl: String,
    statusUrl: String,
    diffUrl: String,
    cleanUrl: String,
    confirm: String,
    cleanConfirm: String,
    newLabel: String,
    staleLabel: String,
    currentLabel: String,
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

  update(event) {
    event.preventDefault()

    this.mode = "import"
    this.showProgress()
    this.sendRequest(patch, this.updateUrlValue)
  }

  remove(event) {
    event.preventDefault()

    if (this.confirmValue && !window.confirm(this.confirmValue)) return

    this.mode = "destroy"
    this.showProgress()
    this.sendRequest(destroy, this.deleteUrlValue)
  }

  async clean(event) {
    event.preventDefault()

    if (this.cleanConfirmValue && !window.confirm(this.cleanConfirmValue)) return

    this.mode = "destroy"
    this.showProgress()

    try {
      const response = await destroy(this.cleanUrlValue, { responseKind: "json" })
      if (!response.ok) throw new Error(`HTTP ${response.statusCode}`)

      window.location.reload()
    } catch (error) {
      this.showError(error.message)
    }
  }

  async kickoffUpdate() {
    this.mode = "import"
    this.showProgress()

    try {
      const response = await patch(this.updateUrlValue, { responseKind: "json" })

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
      const response = await destroy(this.cleanUrlValue, { responseKind: "json" })
      if (!response.ok) throw new Error(`HTTP ${response.statusCode}`)

      return true
    } catch (error) {
      this.showError(error.message)

      return false
    }
  }

  async resync() {
    this.showChecking()

    try {
      const response = await get(this.diffUrlValue, { responseKind: "json" })
      if (!response.ok) throw new Error(`HTTP ${response.statusCode}`)

      const body = await response.json
      this.applyDiff(body)
    } catch (error) {
      this.showDiffError(error.message)
    }
  }

  async sendRequest(requestFn, url) {
    try {
      const response = await requestFn(url, { responseKind: "json" })
      if (!response.ok) throw new Error(`HTTP ${response.statusCode}`)

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
      const response = await get(this.statusUrlValue, { responseKind: "json" })
      if (!response.ok) return

      const body = await response.json
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
      window.location.reload()
    } else if (body.destroy_status === "failed") {
      this.stopPolling()
      this.showError(body.destroy_error)
    }
  }

  applyImportStatus(body) {
    if (body.import_status === "success") {
      this.stopPolling()
      window.location.reload()
    } else if (body.import_status === "failed") {
      this.stopPolling()
      this.showError(body.import_error)
    }
  }

  applyDiff(body) {
    const newCount = Number(body.new_count) || 0
    const staleCount = Number(body.stale_count) || 0

    this.renderDiff(newCount, staleCount)
    this.updateCleanButton(staleCount)
  }

  renderDiff(newCount, staleCount) {
    if (!this.hasDiffTarget) return

    const parts = []
    if (newCount > 0) parts.push(`+${newCount} ${this.newLabelValue}`)
    if (staleCount > 0) parts.push(`−${staleCount} ${this.staleLabelValue}`)

    const hasChanges = parts.length > 0
    this.diffTextTarget.textContent = hasChanges ? parts.join(" · ") : this.currentLabelValue
    this.setDiffIcon(hasChanges ? "difference" : "check_circle")
    this.diffTarget.dataset.state = hasChanges ? "changes" : "current"
    this.diffTarget.hidden = false
  }

  updateCleanButton(staleCount) {
    if (!this.hasCleanButtonTarget) return

    this.cleanButtonTarget.disabled = staleCount === 0
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

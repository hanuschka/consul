import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "submitButton",
    "processingPanel",
    "readyPanel",
    "failedPanel",
    "aiDisabledPanel",
    "errorMessage"
  ]

  static values = {
    prepareUrl: String,
    statusUrl: String,
    pollInterval: { type: Number, default: 3000 }
  }

  connect() {
    this.polling = false
    this.pollTimer = null
    this.readyToSubmit = false
  }

  disconnect() {
    this.clearPoll()
  }

  handleSubmit(event) {
    if (this.readyToSubmit) return

    event.preventDefault()
    this.startPrepare()
  }

  startPrepare() {
    this.hideAllPanels()
    this.setSubmitDisabled(true)

    fetch(this.prepareUrlValue, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken(),
        "Content-Type": "application/json"
      },
      credentials: "same-origin"
    })
      .then((response) => response.json())
      .then((data) => this.handlePrepareResponse(data))
      .catch(() => this.showFailedPanel())
  }

  handlePrepareResponse(data) {
    if (data.ai_disabled) {
      this.showAiDisabledPanel()
      this.markReadyAndSubmit()
      return
    }

    if (data.status === "ready") {
      this.markReadyAndSubmit()
      return
    }

    if (data.status === "processing") {
      this.showProcessingPanel()
      this.schedulePoll()
      return
    }

    this.showFailedPanel()
  }

  schedulePoll() {
    this.clearPoll()
    this.polling = true
    this.pollTimer = setTimeout(() => this.checkStatus(), this.pollIntervalValue)
  }

  clearPoll() {
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)
      this.pollTimer = null
    }
    this.polling = false
  }

  checkStatus() {
    fetch(this.statusUrlValue, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
      .then((response) => response.json())
      .then((data) => this.handleStatusResponse(data))
      .catch(() => this.schedulePoll())
  }

  handleStatusResponse(data) {
    if (data.ai_disabled) {
      this.clearPoll()
      this.showAiDisabledPanel()
      this.markReadyAndSubmit()
      return
    }

    if (data.ready) {
      this.clearPoll()
      this.markReadyAndSubmit()
      return
    }

    if (data.pdf_formatted_status === "failed") {
      this.clearPoll()
      this.showFailedPanel(data.pdf_formatted_error)
      return
    }

    this.schedulePoll()
  }

  retry(event) {
    event.preventDefault()
    this.startPrepare()
  }

  markReadyAndSubmit() {
    this.readyToSubmit = true
    this.setSubmitDisabled(false)
    this.formTarget.requestSubmit()
  }

  hideAllPanels() {
    [
      this.processingPanelTarget,
      this.readyPanelTarget,
      this.failedPanelTarget,
      this.aiDisabledPanelTarget
    ].forEach((panel) => {
      panel.hidden = true
    })
  }

  showProcessingPanel() {
    this.hideAllPanels()
    this.processingPanelTarget.hidden = false
  }

  showFailedPanel(errorMessage) {
    this.hideAllPanels()
    this.failedPanelTarget.hidden = false
    this.setSubmitDisabled(false)

    if (this.hasErrorMessageTarget && errorMessage) {
      this.errorMessageTarget.textContent = errorMessage
    }
  }

  showAiDisabledPanel() {
    this.hideAllPanels()
    this.aiDisabledPanelTarget.hidden = false
  }

  setSubmitDisabled(disabled) {
    if (!this.hasSubmitButtonTarget) return

    this.submitButtonTarget.disabled = disabled
    this.submitButtonTarget.setAttribute("aria-busy", disabled ? "true" : "false")
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }
}

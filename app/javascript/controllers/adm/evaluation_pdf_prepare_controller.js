import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "submitButton",
    "formRegion",
    "progressRegion",
    "summaryBody",
    "progressMeta",
    "progressBar",
    "progressBarFill",
    "stepsList",
    "stepTemplate",
    "failedPanel",
    "aiDisabledPanel",
    "errorMessage"
  ]

  static values = {
    prepareUrl: String,
    statusUrl: String,
    backUrl: String,
    pollInterval: { type: Number, default: 3000 }
  }

  connect() {
    this.polling = false
    this.pollTimer = null
    this.readyToSubmit = false
    this.preparing = false
    this.renderedStepKeys = []
  }

  disconnect() {
    this.clearPoll()
  }

  handleSubmit(event) {
    if (this.readyToSubmit) return

    event.preventDefault()
    if (this.preparing) return

    this.preparing = true
    this.captureSelectedSummary()
    this.startPrepare()
  }

  startPrepare() {
    this.hideTerminalPanels()
    this.showProgressRegion()
    this.renderPlaceholderStep()

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
    this.renderProgress(data.progress)

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
    this.hideTerminalPanels()
    this.startPrepare()
  }

  markReadyAndSubmit() {
    this.readyToSubmit = true
    this.formTarget.requestSubmit()
    this.navigateBack()
  }

  navigateBack() {
    if (!this.hasBackUrlValue || this.backUrlValue.length === 0) return

    setTimeout(() => {
      window.location.href = this.backUrlValue
    }, 250)
  }

  showProgressRegion() {
    this.formRegionTarget.hidden = true
    this.progressRegionTarget.hidden = false
  }

  showFormRegion() {
    this.formRegionTarget.hidden = false
    this.progressRegionTarget.hidden = true
  }

  hideTerminalPanels() {
    this.failedPanelTarget.hidden = true
    this.aiDisabledPanelTarget.hidden = true
  }

  showFailedPanel(errorMessage) {
    this.showFormRegion()
    this.failedPanelTarget.hidden = false

    if (this.hasErrorMessageTarget && errorMessage) {
      this.errorMessageTarget.textContent = errorMessage
    }
  }

  showAiDisabledPanel() {
    this.aiDisabledPanelTarget.hidden = false
  }

  captureSelectedSummary() {
    const sections = []

    const reportCheckbox = this.formTarget.querySelector("#pdf_options_include_report")
    if (reportCheckbox && reportCheckbox.checked) {
      sections.push({
        title: reportCheckbox.closest("label").querySelector("strong").textContent,
        items: []
      })
    }

    const phaseToggles = this.formTarget.querySelectorAll("input[name='pdf_options[phase_ids][]']")
    phaseToggles.forEach((phaseInput) => {
      if (!phaseInput.checked) return

      const phaseId = phaseInput.value
      const phaseLabel = phaseInput.closest("label").querySelector("strong").textContent
      const sectionInputs = this.formTarget.querySelectorAll(
        `input[name='pdf_options[sections][${phaseId}][]']`
      )

      const items = []
      sectionInputs.forEach((sectionInput) => {
        if (!sectionInput.checked) return

        const label = sectionInput.closest("label").textContent.trim()
        items.push(label)
      })

      sections.push({ title: phaseLabel, items: items })
    })

    this.renderSummary(sections)
  }

  renderSummary(sections) {
    const html = sections.map((section) => this.summarySectionHtml(section)).join("")
    this.summaryBodyTarget.innerHTML = html
  }

  summarySectionHtml(section) {
    const itemsHtml = section.items
      .map((item) => `<li>${this.escape(item)}</li>`)
      .join("")
    const itemsBlock = section.items.length > 0
      ? `<ul class="pdf-progress-region__summary-items">${itemsHtml}</ul>`
      : ""

    return `
      <div class="pdf-progress-region__summary-section">
        <div class="pdf-progress-region__summary-title">${this.escape(section.title)}</div>
        ${itemsBlock}
      </div>
    `
  }

  renderProgress(progress) {
    if (!progress) return

    const steps = progress.steps || []
    const total = progress.total || steps.length || 0
    const completed = progress.completed || 0

    this.renderProgressMeta(completed, total)
    this.renderProgressBar(completed, total)
    this.renderSteps(steps)
  }

  renderProgressMeta(completed, total) {
    if (total === 0) {
      this.progressMetaTarget.textContent = ""
      return
    }

    this.progressMetaTarget.textContent = `${completed} / ${total}`
  }

  renderProgressBar(completed, total) {
    const percent = total > 0 ? Math.round((completed / total) * 100) : 0
    this.progressBarFillTarget.style.width = `${percent}%`
    this.progressBarTarget.setAttribute("aria-valuenow", String(percent))
  }

  renderSteps(steps) {
    if (steps.length === 0) {
      this.renderPlaceholderStep()
      return
    }

    const currentKeys = steps.map((s) => s.key).join("|")
    const lastKeys = this.renderedStepKeys.join("|")

    if (currentKeys === lastKeys) {
      this.updateStepStatuses(steps)
      return
    }

    this.renderedStepKeys = steps.map((s) => s.key)
    this.stepsListTarget.innerHTML = ""

    steps.forEach((step) => {
      const node = this.stepTemplateTarget.content.firstElementChild.cloneNode(true)
      node.dataset.stepKey = step.key
      node.dataset.stepStatus = step.status
      node.querySelector(".pdf-progress-region__step-label").textContent = step.label
      this.stepsListTarget.appendChild(node)
    })
  }

  renderPlaceholderStep() {
    this.renderedStepKeys = []
    this.stepsListTarget.innerHTML = ""

    const node = this.stepTemplateTarget.content.firstElementChild.cloneNode(true)
    node.dataset.stepKey = "__placeholder__"
    node.dataset.stepStatus = "processing"
    node.querySelector(".pdf-progress-region__step-label").textContent =
      this.stepTemplateTarget.dataset.placeholderLabel || "Preparing…"

    this.stepsListTarget.appendChild(node)
  }

  updateStepStatuses(steps) {
    const nodes = this.stepsListTarget.querySelectorAll(".pdf-progress-region__step")
    steps.forEach((step, idx) => {
      const node = nodes[idx]
      if (!node) return

      node.dataset.stepStatus = step.status
    })
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = String(text == null ? "" : text)
    return div.innerHTML
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }
}

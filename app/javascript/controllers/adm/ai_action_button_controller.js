import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "progress", "inlineSpinner"]
  static values = {
    statusUrl: String,
    progressMode: { type: String, default: "swap" },
    pollInterval: { type: Number, default: 4000 },
    loading: { type: Boolean, default: false }
  }

  connect() {
    if (!this.loadingValue) return
    if (!this.hasStatusUrlValue || this.statusUrlValue.length === 0) return

    this.schedulePoll()
  }

  start() {
    if (this.progressModeValue === "inline") {
      this.showInlineProgress()
    } else {
      this.swapToProgress()
    }

    if (this.hasStatusUrlValue && this.statusUrlValue.length > 0) {
      this.schedulePoll()
    }
  }

  swapToProgress() {
    const buttonWidth = this.buttonTarget.offsetWidth
    if (buttonWidth > 0) {
      this.progressTarget.style.minWidth = `${buttonWidth}px`
    }

    this.buttonTarget.hidden = true
    this.progressTarget.hidden = false
  }

  showInlineProgress() {
    this.buttonTarget.classList.add("-loading")
    this.buttonTarget.setAttribute("aria-busy", "true")
    this.buttonTarget.style.pointerEvents = "none"
  }

  schedulePoll() {
    this.clearPoll()
    this.pollTimer = setTimeout(() => this.checkStatus(), this.pollIntervalValue)
  }

  clearPoll() {
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)
      this.pollTimer = null
    }
  }

  checkStatus() {
    fetch(this.statusUrlValue, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
      .then((response) => this.handleStatusResponse(response))
      .catch(() => this.schedulePoll())
  }

  handleStatusResponse(response) {
    if (!response.ok) {
      this.schedulePoll()
      return
    }

    response.json()
      .then((data) => {
        if (data.status === "completed" || data.status === "failed") {
          this.clearPoll()
          window.location.reload()
          return
        }

        this.schedulePoll()
      })
      .catch(() => this.schedulePoll())
  }

  disconnect() {
    this.clearPoll()
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "loading"]
  static values = {
    statusUrl: String,
    interval: { type: Number, default: 4000 },
    confirm: String
  }

  connect() {
    this.pollTimer = null
    this.regenerating = false

    if (this.isProcessing()) {
      this.regenerating = true
      this.schedulePoll()
    }
  }

  disconnect() {
    this.clearPoll()
  }

  start(event) {
    event.preventDefault()
    if (this.regenerating) return

    if (this.hasConfirmValue && this.confirmValue.length > 0) {
      if (!window.confirm(this.confirmValue)) return
    }

    this.regenerating = true

    const triggerEl = event.currentTarget
    const url = triggerEl.getAttribute("href") || triggerEl.dataset.url
    if (!url) return

    this.showLoading()

    fetch(url, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin"
    })
      .then((response) => response.json())
      .then(() => this.schedulePoll())
      .catch(() => this.schedulePoll())
  }

  schedulePoll() {
    if (this.statusUrlValue.length === 0) return

    this.clearPoll()
    this.pollTimer = setTimeout(() => this.checkStatus(), this.intervalValue)
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
      .then((response) => response.json())
      .then((data) => this.handleStatusResponse(data))
      .catch(() => this.schedulePoll())
  }

  handleStatusResponse(data) {
    if (data.status === "completed" || data.status === "failed") {
      this.clearPoll()
      window.location.reload()
      return
    }

    this.schedulePoll()
  }

  showLoading() {
    if (this.hasContentTarget) {
      this.contentTarget.hidden = true
    }
    if (this.hasLoadingTarget) {
      this.loadingTarget.hidden = false
    }
  }

  isProcessing() {
    return this.hasLoadingTarget && !this.loadingTarget.hidden
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.getAttribute("content") : ""
  }
}

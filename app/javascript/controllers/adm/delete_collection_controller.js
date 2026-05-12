import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["progress", "trigger"]

  connect() {
    this.handleFetchStart = this.handleFetchStart.bind(this)
    document.addEventListener("turbo:before-fetch-request", this.handleFetchStart)
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this.handleFetchStart)
  }

  handleFetchStart(event) {
    if (!this.hasTriggerTarget) return

    const detail = event.detail || {}
    const requestUrl = detail.url

    if (!requestUrl) return
    if (requestUrl.toString() !== this.triggerTarget.href) return

    this.showProgress()
  }

  showProgress() {
    this.progressTarget.hidden = false
    this.triggerTarget.style.display = "none"
  }
}

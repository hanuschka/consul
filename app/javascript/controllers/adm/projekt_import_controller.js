import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["iframeWrapper", "error", "errorMessage"]

  connect() {
    this.handleGlobalMessage = this.handleGlobalMessage.bind(this)
    window.addEventListener("message", this.handleGlobalMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.handleGlobalMessage)
  }

  handleGlobalMessage(event) {
    const data = event.data
    if (!data || !data.event_type) return

    if (data.event_type === "Consul.projekt_import_complete" && data.params) {
      const redirectPath = data.params.redirect_path
      if (!redirectPath) return

      window.location.href = redirectPath
    }

    if (data.event_type === "Consul.projekt_import_failed" && data.params) {
      this.showError(data.params.error)
    }

    if (data.event_type === "Consul.import_reset_complete") {
      window.location.reload()
    }

  }

  showError(message) {
    this.iframeWrapperTarget.classList.add("-hidden")
    this.errorMessageTarget.textContent = message
    this.errorTarget.classList.remove("-hidden")
  }

  retry() {
    window.location.reload()
  }
}

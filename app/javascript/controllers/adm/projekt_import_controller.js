import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    detailsPath: String
  }

  connect() {
    this.handleMessage = this.handleMessage.bind(this)
    window.addEventListener("message", this.handleMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.handleMessage)
  }

  handleMessage(event) {
    const data = event.data
    if (!data || !data.event_type) return

    if (data.event_type === "import_complete" && data.params) {
      const projektId = data.params.consul_projekt_id
      if (!projektId) return

      const path = this.detailsPathValue.replace(":id", projektId)
      window.location.href = path
    }

    if (data.event_type === "import_failed") {
      console.error("Import failed:", data.params)
    }
  }
}

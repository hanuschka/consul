import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    endpoint: String
  }

  static targets = ["input"]

  triggerPicker(event) {
    event.preventDefault()

    this.inputTarget.value = ""
    this.inputTarget.click()
  }

  async fileChanged(event) {
    const files = event.target.files

    if (!files || files.length === 0) return

    const file = files[0]
    const formData = new FormData()

    formData.append("upload", file)

    try {
      const response = await fetch(this.endpointValue, {
        method: "POST",
        headers: {
          "X-CSRF-TOKEN": this.csrfToken(),
          "Accept": "application/json"
        },
        body: formData
      })
      const data = await response.json()

      if (!response.ok || data.error) {
        throw new Error(data.error ? data.error.message : `HTTP ${response.status}`)
      }

      window.location.reload()
    } catch (error) {
      console.error("Files upload failed", error)
      alert(this.failedMessage())
    } finally {
      event.target.value = ""
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')

    return meta ? meta.getAttribute("content") : ""
  }

  failedMessage() {
    const el = document.querySelector("[data-files-upload-failed-message]")

    return el ? el.getAttribute("data-files-upload-failed-message") : "Upload failed"
  }
}

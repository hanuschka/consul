import { Controller } from "@hotwired/stimulus"
import { addFlashMessage } from "../../utils/adm_flash"

export default class extends Controller {
  static values = {
    endpoint: String
  }

  static targets = ["input", "cropInput"]

  triggerPicker(event) {
    event.preventDefault()

    this.inputTarget.value = ""
    this.inputTarget.click()
  }

  triggerCropPicker(event) {
    event.preventDefault()

    this.cropInputTarget.value = ""
    this.cropInputTarget.click()
  }

  async fileChanged(event) {
    const files = event.target.files

    if (!files || files.length === 0) return

    try {
      await this.uploadFile(files[0])
    } finally {
      event.target.value = ""
    }
  }

  async uploadCropped(event) {
    const file = event.detail.file

    if (!file) return

    await this.uploadFile(file)
  }

  async uploadFile(file) {
    const formData = new FormData()

    formData.append("upload", file)

    this.dispatchProgress("begin")

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

      this.dispatchProgress("complete")
      addFlashMessage(this.successMessage(file.name), "success")
      this.reloadResults()
    } catch (error) {
      console.error("Files upload failed", error)
      this.dispatchProgress("restore")
      addFlashMessage(this.failedMessage(file.name), "danger")
    }
  }

  reloadResults() {
    const frame = document.getElementById("files-index-results")

    if (frame.src) {
      frame.reload()
    } else {
      frame.src = window.location.href
    }
  }

  dispatchProgress(name) {
    this.element.dispatchEvent(
      new CustomEvent(`adm-button-with-progress:${name}`, { bubbles: true })
    )
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')

    return meta ? meta.getAttribute("content") : ""
  }

  successMessage(filename) {
    return this.applyTemplate("data-files-upload-success-template", filename) ||
      `Uploaded ${filename}`
  }

  failedMessage(filename) {
    const templated = this.applyTemplate("data-files-upload-failed-template", filename)
    if (templated) return templated

    const fallback = document.querySelector("[data-files-upload-failed-message]")

    return fallback ? fallback.getAttribute("data-files-upload-failed-message") : "Upload failed"
  }

  applyTemplate(attribute, filename) {
    const el = document.querySelector(`[${attribute}]`)
    if (!el) return null

    return el.getAttribute(attribute).replace("__FILENAME__", filename)
  }
}

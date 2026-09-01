import { Controller } from "@hotwired/stimulus"

const BEGIN_EVENT = "adm-button-with-progress:begin"
const COMPLETE_EVENT = "adm-button-with-progress:complete"
const RESTORE_EVENT = "adm-button-with-progress:restore"
const RENDERER_UNAVAILABLE_STATUS = 503

export default class extends Controller {
  static targets = ["form", "buttonWrapper", "errorDialog"]

  connect() {
    this.handleSubmit = this.handleSubmit.bind(this)
    if (this.hasFormTarget) {
      this.formTarget.addEventListener("submit", this.handleSubmit)
    }
  }

  disconnect() {
    if (this.hasFormTarget) {
      this.formTarget.removeEventListener("submit", this.handleSubmit)
    }
    this.revokeBlobUrl()
  }

  handleSubmit(event) {
    event.preventDefault()
    this.startDownload()
  }

  async startDownload() {
    this.dispatchProgress(BEGIN_EVENT)

    try {
      const response = await fetch(this.buildUrl(), {
        method: "GET",
        credentials: "same-origin"
      })

      if (response.status === RENDERER_UNAVAILABLE_STATUS) {
        this.dispatchProgress(RESTORE_EVENT)
        this.openErrorDialog()

        return
      }

      if (!response.ok) {
        throw new Error(`Server returned ${response.status}`)
      }

      const blob = await response.blob()
      const filename = this.extractFilename(response) || "evaluation.pdf"
      this.triggerDownload(blob, filename)
      this.dispatchProgress(COMPLETE_EVENT)
    } catch (err) {
      console.error("[evaluation_pdf_download]", err)
      this.dispatchProgress(RESTORE_EVENT)
    }
  }

  openErrorDialog() {
    if (!this.hasErrorDialogTarget) return

    this.errorDialogTarget.showModal()
  }

  closeErrorDialog() {
    if (!this.hasErrorDialogTarget) return

    this.errorDialogTarget.close()
  }

  buildUrl() {
    const form = this.formTarget
    const action = form.getAttribute("action") || form.action
    const params = new URLSearchParams(new FormData(form))
    const separator = action.includes("?") ? "&" : "?"

    return `${action}${separator}${params.toString()}`
  }

  extractFilename(response) {
    const header = response.headers.get("Content-Disposition") || ""
    const match = header.match(/filename\*?=(?:UTF-8'')?["']?([^"';]+)["']?/i)

    return match ? decodeURIComponent(match[1]) : null
  }

  triggerDownload(blob, filename) {
    this.revokeBlobUrl()
    this.blobUrl = URL.createObjectURL(blob)

    const anchor = document.createElement("a")
    anchor.href = this.blobUrl
    anchor.download = filename
    anchor.style.display = "none"
    document.body.appendChild(anchor)
    anchor.click()
    document.body.removeChild(anchor)
  }

  revokeBlobUrl() {
    if (this.blobUrl) {
      URL.revokeObjectURL(this.blobUrl)
      this.blobUrl = null
    }
  }

  dispatchProgress(eventName) {
    if (!this.hasButtonWrapperTarget) return

    this.buttonWrapperTarget.dispatchEvent(
      new CustomEvent(eventName, { bubbles: false })
    )
  }
}

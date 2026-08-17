import { Controller } from "@hotwired/stimulus"
import AjaxFetch from "../../shared/ajax_fetch"

// Upload screen: validates files, POSTs multipart to create, then hands off to
// the dedicated loading screen (import show), which polls status and redirects to
// the chat. Navigating to a real URL keeps in-flight analysis reload-safe.
export default class extends Controller {
  static targets = [
    "form", "dropzone", "fileInput", "fileList", "secondary",
    "instructions", "submitButton",
    "error", "progress", "progressLabel", "progressFill", "loaderFiles"
  ]

  static values = {
    createUrl: String,
    maxBytes: Number,
    allowed: String,
    csrf: String,
    progressExtracting: String,
    errorTooLarge: String,
    errorUnsupported: String,
    errorNoFiles: String,
    errorSessionExpired: String,
    errorRequestFailed: String
  }

  connect() {
    this.files = []
    this.bindDragEvents()
    this.renderFileList()
    this.updateVisibility()
    this.hideProgress()
    this.clearError()
  }

  disconnect() {
    this.unbindDragEvents()
  }

  bindDragEvents() {
    this.dragOver = (event) => {
      event.preventDefault()
      this.activeDropTarget()?.classList.add("-drag-over")
    }
    this.dragLeave = (event) => {
      event.preventDefault()
      this.activeDropTarget()?.classList.remove("-drag-over")
    }
    this.drop = (event) => {
      event.preventDefault()
      this.activeDropTarget()?.classList.remove("-drag-over")
      const dropped = Array.from(event.dataTransfer?.files || [])
      if (dropped.length === 0) return
      this.acceptFiles(dropped)
    }

    this.element.addEventListener("dragover", this.dragOver)
    this.element.addEventListener("dragleave", this.dragLeave)
    this.element.addEventListener("drop", this.drop)
  }

  unbindDragEvents() {
    this.element.removeEventListener("dragover", this.dragOver)
    this.element.removeEventListener("dragleave", this.dragLeave)
    this.element.removeEventListener("drop", this.drop)
  }

  activeDropTarget() {
    if (this.hasSecondaryTarget && !this.secondaryTarget.classList.contains("-hidden")) {
      return this.secondaryTarget
    }
    return this.hasDropzoneTarget ? this.dropzoneTarget : null
  }

  updateVisibility() {
    const hasFiles = this.files.length > 0
    if (this.hasDropzoneTarget) this.dropzoneTarget.classList.toggle("-hidden", hasFiles)
    if (this.hasSecondaryTarget) this.secondaryTarget.classList.toggle("-hidden", !hasFiles)
  }

  filesPicked(event) {
    const picked = Array.from(event.target.files || [])
    if (picked.length === 0) return
    this.acceptFiles(picked)
    event.target.value = ""
  }

  acceptFiles(picked) {
    const allowed = this.allowedValue.split(",")
    const accepted = []
    let totalBytes = this.totalBytes()

    for (const file of picked) {
      const ext = (file.name.split(".").pop() || "").toLowerCase()
      if (!allowed.includes(ext)) {
        this.showError(this.errorUnsupportedValue.replace("%{filename}", file.name))
        continue
      }
      if (totalBytes + file.size > this.maxBytesValue) {
        this.showError(this.errorTooLargeValue)
        break
      }
      totalBytes += file.size
      accepted.push(file)
    }

    if (accepted.length === 0) return

    this.files = this.files.concat(accepted)
    this.renderFileList()
    this.updateVisibility()
    this.clearError()
  }

  removeFile(event) {
    const index = Number(event.currentTarget.dataset.index)
    this.files.splice(index, 1)
    this.renderFileList()
    this.updateVisibility()
  }

  resetFiles() {
    this.files = []
    this.renderFileList()
    this.updateVisibility()
    this.clearError()
    if (this.hasFileInputTarget) this.fileInputTarget.value = ""
  }

  totalBytes() {
    return this.files.reduce((sum, file) => sum + file.size, 0)
  }

  renderFileList() {
    if (!this.hasFileListTarget) return

    this.fileListTarget.innerHTML = ""

    this.files.forEach((file, index) => {
      const row = document.createElement("div")
      row.className = "projekt-import-from-file--file-info"

      const icon = document.createElement("span")
      icon.className = "projekt-import-from-file--file-icon"
      icon.setAttribute("aria-hidden", "true")
      const iconGlyph = document.createElement("span")
      iconGlyph.className = "material-symbols-outlined"
      iconGlyph.textContent = "description"
      icon.appendChild(iconGlyph)

      const details = document.createElement("div")
      details.className = "projekt-import-from-file--file-details"
      const name = document.createElement("span")
      name.className = "projekt-import-from-file--file-name"
      name.textContent = file.name
      const size = document.createElement("span")
      size.className = "projekt-import-from-file--file-size"
      size.textContent = this.humanSize(file.size)
      details.appendChild(name)
      details.appendChild(size)

      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "projekt-import-from-file--file-remove"
      remove.dataset.index = index.toString()
      remove.dataset.action = "click->projekt-imports--from-file#removeFile"
      remove.setAttribute("aria-label", "Remove")
      remove.textContent = "×"

      row.appendChild(icon)
      row.appendChild(details)
      row.appendChild(remove)
      this.fileListTarget.appendChild(row)
    })
  }

  humanSize(bytes) {
    const units = ["B", "KB", "MB", "GB"]
    let size = bytes
    let unit = 0
    while (size > 1024 && unit < units.length - 1) {
      size /= 1024
      unit += 1
    }
    return `${size.toFixed(1)} ${units[unit]}`
  }

  submit(event) {
    event.preventDefault()

    if (this.files.length === 0) {
      this.showError(this.errorNoFilesValue)
      return
    }

    this.submitButtonTarget.disabled = true
    this.clearError()

    const formData = new FormData()
    this.files.forEach((file) => formData.append("files[]", file))

    if (this.instructionsTarget.value) {
      formData.append("additional_user_instructions", this.instructionsTarget.value)
    }

    this.showProgress()
    this.progressLabelTarget.textContent = this.progressExtractingValue

    AjaxFetch.post(this.createUrlValue, formData)
      .then((data) => {
        window.location.href = data.import_url
      })
      .catch((error) => {
        this.hideProgress()
        this.submitButtonTarget.disabled = false
        this.showError(this.uploadErrorMessage(error))
      })
  }

  uploadErrorMessage(error) {
    const status = error && error.status
    const serverMessage = error && error.data && error.data.error

    if (serverMessage) return serverMessage
    if (status === 401 || status === 403 || status === 422) return this.errorSessionExpiredValue

    if (status) {
      return this.errorRequestFailedValue.replace("%{status}", status)
    }

    return this.errorRequestFailedValue.replace("%{status}", "network")
  }

  showProgress() {
    if (this.hasFormTarget) this.formTarget.hidden = true
    if (this.hasProgressTarget) this.progressTarget.classList.remove("-hidden")

    this.renderLoaderFiles()
  }

  hideProgress() {
    if (this.hasFormTarget) this.formTarget.hidden = false
    if (this.hasProgressTarget) this.progressTarget.classList.add("-hidden")
  }

  renderLoaderFiles() {
    if (!this.hasLoaderFilesTarget) return
    this.loaderFilesTarget.innerHTML = ""
    this.files.forEach((file) => {
      const row = document.createElement("div")
      row.className = "projekt-import-from-file--loader-file-item"
      const icon = document.createElement("span")
      icon.className = "material-symbols-outlined"
      icon.setAttribute("aria-hidden", "true")
      icon.textContent = "description"
      const name = document.createElement("span")
      name.className = "projekt-import-from-file--loader-file-name"
      name.textContent = file.name
      const size = document.createElement("span")
      size.className = "projekt-import-from-file--loader-file-size"
      size.textContent = this.humanSize(file.size)
      row.appendChild(icon)
      row.appendChild(name)
      row.appendChild(size)
      this.loaderFilesTarget.appendChild(row)
    })
  }

  showError(message) {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    if (!this.hasErrorTarget) return

    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }
}

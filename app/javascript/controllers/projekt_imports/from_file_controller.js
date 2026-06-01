import { Controller } from "@hotwired/stimulus"
import AjaxFetch from "../../shared/ajax_fetch"

// Upload screen: validates files, POSTs multipart to create, then polls status
// every 2 s until the import transitions to chatting (or fails).
export default class extends Controller {
  static targets = [
    "form", "dropzone", "fileInput", "fileList", "secondary",
    "instructions", "generateImage", "submitButton",
    "error", "progress", "progressLabel", "progressFill", "loaderFiles"
  ]

  static values = {
    createUrl: String,
    maxBytes: Number,
    allowed: String,
    csrf: String,
    pollInterval: { type: Number, default: 1000 },
    progressExtracting: String,
    progressProcessing: String,
    progressChatting: String,
    errorTooLarge: String,
    errorUnsupported: String,
    errorNoFiles: String
  }

  connect() {
    this.files = []
    this.pollTimer = null
    this.bindDragEvents()
    this.updateVisibility()
  }

  disconnect() {
    this.clearPollTimer()
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
    formData.append("generate_image", this.generateImageTarget.checked ? "true" : "false")

    if (this.instructionsTarget.value) {
      formData.append("additional_user_instructions", this.instructionsTarget.value)
    }

    this.showProgress()
    this.progressLabelTarget.textContent = this.progressExtractingValue

    AjaxFetch.post(this.createUrlValue, formData)
      .then((data) => {
        this.pollStatus(data.status_url)
      })
      .catch((error) => {
        this.hideProgress()
        this.submitButtonTarget.disabled = false
        const message = (error && error.data && error.data.error) || this.errorNoFilesValue
        this.showError(message)
      })
  }

  showProgress() {
    if (this.hasFormTarget) this.formTarget.hidden = true
    if (this.hasProgressTarget) this.progressTarget.classList.remove("-hidden")

    this.renderLoaderFiles()
    this.setProgressPercent(15)
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

  setProgressPercent(percent) {
    if (!this.hasProgressFillTarget) return
    this.progressFillTarget.style.width = `${Math.max(0, Math.min(100, percent))}%`
  }

  pollStatus(url) {
    this.clearPollTimer()
    AjaxFetch.get(url)
      .then((data) => this.handleStatus(data, url))
      .catch(() => this.schedulePoll(url))
  }

  schedulePoll(url) {
    this.pollTimer = setTimeout(() => this.pollStatus(url), this.pollIntervalValue)
  }

  clearPollTimer() {
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)
      this.pollTimer = null
    }
  }

  handleStatus(data, url) {
    switch (data.status) {
      case "extracting":
        this.progressLabelTarget.textContent = this.progressExtractingValue
        this.setProgressPercent(35)
        this.schedulePoll(url)
        break
      case "processing":
        this.progressLabelTarget.textContent = this.progressProcessingValue
        this.setProgressPercent(70)
        this.schedulePoll(url)
        break
      case "chatting":
        this.progressLabelTarget.textContent = this.progressChattingValue
        this.setProgressPercent(100)
        window.location.href = data.chat_url
        break
      case "failed":
        this.clearPollTimer()
        this.hideProgress()
        this.submitButtonTarget.disabled = false
        this.showError(data.error || "")
        break
      default:
        this.schedulePoll(url)
    }
  }

  showError(message) {
    this.errorTarget.textContent = message
    this.errorTarget.hidden = false
  }

  clearError() {
    this.errorTarget.textContent = ""
    this.errorTarget.hidden = true
  }
}

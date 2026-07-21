import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "endpointUrl",
    "loadCollectionsButton",
    "tree",
    "treeEmpty",
    "treeEmptyText",
    "treeNodes",
    "createResourceCheckbox",
    "importButton",
    "statusBadge",
    "actions",
    "progress",
    "progressCount",
    "progressResource",
    "progressResourceIcon",
    "progressResourceText",
    "fileInput",
    "fileRows"
  ]

  static values = {
    endpoints: Object,
    initialStatus: Object,
    progressCountTemplate: String,
    progressCountToken: String
  }

  connect() {
    this.pollIntervalId = null
    this.selectedCollectionIds = new Set()
    this.attachedFiles = []
    this.fileSequence = 0
    this.defaultEmptyText = this.hasTreeEmptyTextTarget ? this.treeEmptyTextTarget.textContent : ""
    this.lastStatus = this.initialStatusValue.status

    if (this.initialStatusValue.status === "running") {
      this.applyStatus(this.initialStatusValue)
      this.startStatusPolling()
    }
  }

  disconnect() {
    this.stopStatusPolling()
  }

  async loadCollections() {
    const url = this.endpointUrlTarget.value.trim()
    if (!url) return

    this.loadCollectionsButtonTarget.disabled = true

    try {
      const requestUrl =
        `${this.endpointsValue.collections_url}?endpoint_url=${encodeURIComponent(url)}`
      const response = await fetch(requestUrl, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const body = await response.json()
      this.renderTree(body.root)
    } catch (error) {
      this.renderHint(error.message)
    } finally {
      this.loadCollectionsButtonTarget.disabled = false
    }
  }

  renderHint(message) {
    this.treeNodesTarget.innerHTML = ""
    this.treeEmptyTextTarget.textContent = String(message || "") || this.defaultEmptyText
    this.showEmptyState()
  }

  renderTree(root) {
    this.selectedCollectionIds.clear()
    this.updateImportButton()
    this.treeNodesTarget.innerHTML = ""

    if (!root) {
      this.renderHint("")
      return
    }

    this.treeNodesTarget.appendChild(this.buildNode(root, true))
    this.hideEmptyState()
  }

  showEmptyState() {
    this.treeEmptyTarget.hidden = false
  }

  hideEmptyState() {
    this.treeEmptyTarget.hidden = true
  }

  buildNode(node, isRoot) {
    const hasChildren = Array.isArray(node.children) && node.children.length > 0

    if (!hasChildren) {
      return this.buildLeaf(node)
    }

    const details = document.createElement("details")
    details.className = "masterportal-import-panel--tree-node"
    details.open = isRoot

    const summary = document.createElement("summary")
    summary.className = "masterportal-import-panel--tree-summary"
    summary.textContent = node.label || node.title || node.id || ""
    details.appendChild(summary)

    const ul = document.createElement("ul")
    ul.className = "masterportal-import-panel--tree-children"

    const sortedChildren = node.children
      .slice()
      .sort((a, b) => this.nodeSortLabel(a).localeCompare(
        this.nodeSortLabel(b), "de", { sensitivity: "base", numeric: true }
      ))

    sortedChildren.forEach((child) => {
      const li = document.createElement("li")
      li.appendChild(this.buildNode(child, false))
      ul.appendChild(li)
    })

    details.appendChild(ul)
    return details
  }

  nodeSortLabel(node) {
    return (node.label || node.title || node.id || "").toString()
  }

  buildLeaf(node) {
    const label = document.createElement("label")
    label.className = "masterportal-import-panel--tree-leaf"

    const input = document.createElement("input")
    input.type = "checkbox"
    input.value = node.id
    input.addEventListener("change", () => this.toggleCollection(node.id, input.checked))
    label.appendChild(input)

    const countPart = node.number_matched ? ` (${node.number_matched})` : ""
    const text = document.createElement("span")
    text.textContent = ` ${node.title || node.id || ""}${countPart}`
    label.appendChild(text)

    return label
  }

  toggleCollection(id, checked) {
    if (checked) {
      this.selectedCollectionIds.add(id)
    } else {
      this.selectedCollectionIds.delete(id)
    }

    this.updateImportButton()
  }

  updateImportButton() {
    this.importButtonTarget.disabled = !this.hasSelection() && !this.hasValidFiles()
  }

  hasSelection() {
    return this.selectedCollectionIds.size > 0
  }

  hasValidFiles() {
    return this.attachedFiles.some((entry) => entry.valid)
  }

  get fileConfig() {
    if (!this._fileConfig) {
      this._fileConfig = JSON.parse(this.fileInputTarget.dataset.config)
    }

    return this._fileConfig
  }

  openFileDialog() {
    this.fileInputTarget.click()
  }

  addFiles(event) {
    const files = Array.from(event.target.files || [])
    files.forEach((file) => this.addFile(file))

    event.target.value = ""
    this.updateImportButton()
  }

  addFile(file) {
    const entry = { id: `mp-file-${this.fileSequence++}`, file, valid: false }
    this.attachedFiles.push(entry)

    const row = this.buildFileRow(entry)
    this.fileRowsTarget.appendChild(row)
    this.fileRowsTarget.hidden = false

    this.validateFile(entry, row)
  }

  validateFile(entry, row) {
    const config = this.fileConfig

    if (entry.file.size > config.maxFileSize) {
      this.markRowInvalid(entry, row, config.errors.too_large)
      return
    }

    const reader = new FileReader()
    reader.onload = () => this.handleFileParsed(entry, row, reader.result)
    reader.onerror = () => this.markRowInvalid(entry, row, config.errors.generic)
    reader.readAsText(entry.file)
  }

  handleFileParsed(entry, row, text) {
    const config = this.fileConfig
    const reason = this.geojsonError(text)

    if (reason) {
      this.markRowInvalid(entry, row, config.errors[reason] || config.errors.generic)
      return
    }

    this.markRowValid(entry, row)
    this.updateImportButton()
  }

  geojsonError(text) {
    if (!text || !text.trim()) return "empty"

    let body

    try {
      body = JSON.parse(text)
    } catch (error) {
      return "invalid_json"
    }

    if (!body || body.type !== "FeatureCollection") return "not_feature_collection"

    return null
  }

  markRowInvalid(entry, row, message) {
    entry.valid = false
    row.classList.add("-invalid")

    const errorElement = row.querySelector(".masterportal-file-upload--row-error")
    errorElement.textContent = message
    errorElement.hidden = false

    this.updateImportButton()
  }

  markRowValid(entry, row) {
    entry.valid = true
    row.classList.remove("-invalid")

    const errorElement = row.querySelector(".masterportal-file-upload--row-error")
    errorElement.textContent = ""
    errorElement.hidden = true
  }

  removeFile(event) {
    const row = event.currentTarget.closest("[data-file-id]")
    if (!row) return

    const id = row.dataset.fileId
    this.attachedFiles = this.attachedFiles.filter((entry) => entry.id !== id)
    row.remove()

    if (this.attachedFiles.length === 0) this.fileRowsTarget.hidden = true

    this.updateImportButton()
  }

  buildFileRow(entry) {
    const config = this.fileConfig
    const row = document.createElement("li")
    row.className = "masterportal-file-upload--row"
    row.dataset.fileId = entry.id

    row.appendChild(this.buildRowIcon())
    row.appendChild(this.buildRowMain(entry, config))
    row.appendChild(this.buildRowRemoveButton(config))

    return row
  }

  buildRowIcon() {
    const icon = document.createElement("span")
    icon.className = "masterportal-file-upload--row-icon material-symbols-outlined"
    icon.setAttribute("aria-hidden", "true")
    icon.textContent = "description"

    return icon
  }

  buildRowMain(entry, config) {
    const main = document.createElement("div")
    main.className = "masterportal-file-upload--row-main"

    const filename = document.createElement("span")
    filename.className = "masterportal-file-upload--row-filename"
    filename.textContent = `${config.labels.fromFile} ${entry.file.name}`
    main.appendChild(filename)

    const inputId = `masterportal-file-name-${entry.id}`

    const label = document.createElement("label")
    label.className = "masterportal-file-upload--row-name-label"
    label.setAttribute("for", inputId)
    label.textContent = config.labels.nameLabel
    main.appendChild(label)

    const nameInput = document.createElement("input")
    nameInput.type = "text"
    nameInput.id = inputId
    nameInput.className = "masterportal-file-upload--row-name-input"
    nameInput.value = this.defaultName(entry.file.name)
    nameInput.placeholder = config.labels.namePlaceholder
    main.appendChild(nameInput)

    const hint = document.createElement("span")
    hint.className = "masterportal-file-upload--row-name-hint"
    hint.textContent = config.labels.nameHint
    main.appendChild(hint)

    const error = document.createElement("span")
    error.className = "masterportal-file-upload--row-error"
    error.hidden = true
    main.appendChild(error)

    return main
  }

  buildRowRemoveButton(config) {
    const button = document.createElement("button")
    button.type = "button"
    button.className = "masterportal-file-upload--row-remove"
    button.title = config.labels.remove
    button.setAttribute("data-action", "adm--masterportal-import-panel#removeFile")

    const icon = document.createElement("span")
    icon.className = "material-symbols-outlined"
    icon.setAttribute("aria-hidden", "true")
    icon.textContent = "close"
    button.appendChild(icon)

    return button
  }

  defaultName(filename) {
    return filename.replace(/\.[^./\\]+$/, "")
  }

  async startImport() {
    const validFiles = this.attachedFiles.filter((entry) => entry.valid)
    if (!this.hasSelection() && validFiles.length === 0) return

    const createRecords =
      this.hasCreateResourceCheckboxTarget && this.createResourceCheckboxTarget.checked

    this.applyStatus({
      status: "running",
      last_imported_count: 0,
      create_resource: createRecords
    })

    const formData = new FormData()
    formData.append("projekt_phase_id", this.endpointsValue.projekt_phase_id)
    formData.append("endpoint_url", this.endpointUrlTarget.value.trim())
    formData.append("create_domain_records", createRecords ? "1" : "0")
    this.selectedCollectionIds.forEach((id) => formData.append("collection_ids[]", id))
    this.appendFilesTo(formData, validFiles)

    try {
      const response = await fetch(this.endpointsValue.create_url, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken() },
        body: formData
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.startStatusPolling()
    } catch (error) {
      this.applyStatus({ status: "failed", error: error.message })
    }
  }

  appendFilesTo(formData, entries) {
    entries.forEach((entry) => {
      const row = this.fileRowsTarget.querySelector(`[data-file-id="${entry.id}"]`)
      const nameInput = row && row.querySelector(".masterportal-file-upload--row-name-input")

      formData.append("files[]", entry.file)
      formData.append("file_names[]", nameInput ? nameInput.value : "")
    })
  }

  startStatusPolling() {
    this.stopStatusPolling()
    this.pollIntervalId = window.setInterval(() => this.fetchStatus(), 3000)
  }

  stopStatusPolling() {
    if (this.pollIntervalId !== null) {
      window.clearInterval(this.pollIntervalId)
      this.pollIntervalId = null
    }
  }

  async fetchStatus() {
    const url =
      `${this.endpointsValue.status_url}?projekt_phase_id=${this.endpointsValue.projekt_phase_id}`

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const body = await response.json()
      this.applyStatus(body)

      if (body.status !== "running") {
        this.stopStatusPolling()
      }
    } catch (error) {
    }
  }

  applyStatus(status) {
    const wasRunning = this.lastStatus === "running"
    const nextStatus = status.status

    this.setStatusBadge(status)
    this.setRunningUi(status)
    this.lastStatus = nextStatus

    if (wasRunning && nextStatus === "success") {
      this.stopStatusPolling()
      this.redirectToSummary()
    }
  }

  redirectToSummary() {
    const url = new URL(window.location.href)
    url.searchParams.set("masterportal_import", "success")
    url.hash = "masterportal-pins-summary"
    window.location.assign(url.toString())
  }

  setRunningUi(status) {
    const isRunning = status.status === "running"
    this.progressTarget.hidden = !isRunning
    this.actionsTarget.style.display = isRunning ? "none" : ""
    this.endpointUrlTarget.disabled = isRunning
    this.loadCollectionsButtonTarget.disabled = isRunning

    if (isRunning) {
      this.importButtonTarget.disabled = true
      this.updateProgressCount(status.last_imported_count)
      this.updateProgressResource(status.create_resource)
    } else {
      this.updateImportButton()
    }
  }

  updateProgressResource(createResource) {
    if (!this.hasProgressResourceTarget) return
    if (typeof createResource !== "boolean") return

    const element = this.progressResourceTarget
    const iconElement = this.progressResourceIconTarget
    const textElement = this.progressResourceTextTarget

    if (createResource) {
      iconElement.textContent = "check_circle"
      textElement.textContent = element.dataset.createOnText
      element.dataset.state = "on"
    } else {
      iconElement.textContent = "do_not_disturb_on"
      textElement.textContent = element.dataset.createOffText
      element.dataset.state = "off"
    }

    element.hidden = false
  }

  updateProgressCount(count) {
    const number = Number.isFinite(count) ? count : 0
    this.progressCountTarget.textContent = this.progressCountTemplateValue
      .replace(this.progressCountTokenValue, String(number))
  }

  setStatusBadge(status) {
    const badge = this.statusBadgeTarget
    const state = status.status || "pending"
    badge.setAttribute("data-status", state)

    const iconElement = badge.querySelector(".masterportal-import-panel--status-icon")
    if (iconElement) {
      iconElement.textContent = this.statusIconName(state)
    }

    const textElement = badge.querySelector(".masterportal-import-panel--status-text")
    if (textElement) {
      textElement.textContent = status.error || this.statusFallbackText(state)
    }
  }

  statusIconName(state) {
    if (state === "running") return "progress_activity"
    if (state === "success") return "check_circle"
    if (state === "failed") return "error"
    return "schedule"
  }

  statusFallbackText(state) {
    if (state === "running") return "Läuft…"
    if (state === "success") return "Erfolgreich"
    if (state === "failed") return "Fehlgeschlagen"
    return "Bereit"
  }

  csrfToken() {
    const el = document.querySelector("meta[name='csrf-token']")
    return el ? el.getAttribute("content") : ""
  }
}

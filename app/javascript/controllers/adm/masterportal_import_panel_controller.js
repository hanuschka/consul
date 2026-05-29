import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "endpointUrl",
    "loadCollectionsButton",
    "tree",
    "createResourceCheckbox",
    "importButton",
    "statusBadge",
    "actions",
    "progress",
    "progressCount",
    "progressResource",
    "progressResourceIcon",
    "progressResourceText"
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
    this.treeTarget.innerHTML = ""

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
    const p = document.createElement("p")
    p.className = "masterportal-import-panel--hint"
    p.textContent = String(message)
    this.treeTarget.innerHTML = ""
    this.treeTarget.appendChild(p)
  }

  renderTree(root) {
    this.selectedCollectionIds.clear()
    this.updateImportButton()
    this.treeTarget.innerHTML = ""

    if (!root) {
      this.renderHint("")
      return
    }

    const rootNode = this.buildNode(root, true)
    this.treeTarget.appendChild(rootNode)
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
    this.importButtonTarget.disabled = this.selectedCollectionIds.size === 0
  }

  async startImport() {
    if (this.selectedCollectionIds.size === 0) return

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
      window.location.reload()
    }
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

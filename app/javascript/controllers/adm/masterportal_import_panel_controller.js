import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "endpointUrl",
    "loadCollectionsButton",
    "tree",
    "createResourceCheckbox",
    "importButton",
    "statusBadge"
  ]

  static values = {
    endpoints: Object,
    initialStatus: Object
  }

  connect() {
    this.pollIntervalId = null
    this.selectedCollectionIds = new Set()

    if (this.initialStatusValue.status === "running") {
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

    node.children.forEach((child) => {
      const li = document.createElement("li")
      li.appendChild(this.buildNode(child, false))
      ul.appendChild(li)
    })

    details.appendChild(ul)
    return details
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

    this.importButtonTarget.disabled = true

    const createRecords =
      this.hasCreateResourceCheckboxTarget && this.createResourceCheckboxTarget.checked

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

      const body = await response.json()
      this.applyStatus(body)
      this.startStatusPolling()
    } catch (error) {
      this.setStatusBadge({ status: "failed", error: error.message })
    } finally {
      this.importButtonTarget.disabled = false
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
    this.setStatusBadge(status)
  }

  setStatusBadge(status) {
    const badge = this.statusBadgeTarget
    badge.setAttribute("data-status", status.status || "pending")
    badge.textContent = status.error || status.status || ""
  }

  csrfToken() {
    const el = document.querySelector("meta[name='csrf-token']")
    return el ? el.getAttribute("content") : ""
  }
}

import { Controller } from "@hotwired/stimulus"

// Column visibility toggle for kern-table.
// Reads th[data-field] headers, builds checkboxes, persists selection in localStorage.
export default class extends Controller {
  static values = {
    storageKey: String,
    defaults: String // comma-separated default visible columns
  }

  static targets = ["table", "menu", "list"]

  connect() {
    this.checkboxByField = new Map()
    this.visibleByField = new Map()
    this.fields = []

    this.buildCheckboxes()
    this.applyFromStorage()
    this.observeRowChanges()
  }

  disconnect() {
    if (this.rowObserver) this.rowObserver.disconnect()
  }

  observeRowChanges() {
    const tbody = this.tableTarget.querySelector("tbody")
    if (!tbody) return

    this.rowObserver = new MutationObserver(mutations => this.handleRowMutations(mutations))
    this.rowObserver.observe(tbody, { childList: true })
  }

  handleRowMutations(mutations) {
    mutations.forEach(m => m.addedNodes.forEach(node => this.applyVisibilityToNode(node)))
  }

  applyVisibilityToNode(node) {
    if (node.nodeType !== Node.ELEMENT_NODE) return

    node.querySelectorAll("[data-field]").forEach(el => {
      const show = this.visibleByField.get(el.dataset.field)
      el.classList.toggle("d-none", !show)
    })
  }

  toggle() {
    this.menuTarget.classList.toggle("adm-column-selector__menu--open")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("adm-column-selector__menu--open")
    }
  }

  buildCheckboxes() {
    const headers = this.tableTarget.querySelectorAll("thead th[data-field]")
    headers.forEach(header => this.appendCheckbox(header))
  }

  appendCheckbox(header) {
    const field = header.dataset.field
    const labelEl = header.querySelector("[id$='-label']")
    const text = labelEl ? labelEl.textContent.trim() : header.textContent.trim()

    this.fields.push(field)

    const label = document.createElement("label")
    label.className = "adm-column-selector__item"

    const checkbox = document.createElement("input")
    checkbox.type = "checkbox"
    checkbox.dataset.field = field
    checkbox.className = "adm-column-selector__checkbox"
    checkbox.addEventListener("change", () => this.toggleColumn(field, checkbox.checked))

    const span = document.createElement("span")
    span.textContent = text

    label.appendChild(checkbox)
    label.appendChild(span)
    this.listTarget.appendChild(label)
    this.checkboxByField.set(field, checkbox)
  }

  applyFromStorage() {
    const saved = this.readStorage()
    const defaults = new Set(this.defaultsValue.split(",").filter(f => f.length > 0))

    this.fields.forEach(field => {
      const show = this.resolveVisibility(field, saved, defaults)
      this.visibleByField.set(field, show)
      this.setColumnVisibility(field, show)
      this.checkboxByField.get(field).checked = show
    })

    this.saveToStorage()
  }

  resolveVisibility(field, saved, defaults) {
    if (saved && saved.visible.includes(field)) return true
    if (saved && saved.hidden.includes(field)) return false

    return defaults.has(field)
  }

  toggleColumn(field, show) {
    this.visibleByField.set(field, show)
    this.setColumnVisibility(field, show)
    this.saveToStorage()
  }

  setColumnVisibility(field, show) {
    this.tableTarget.querySelectorAll(`[data-field="${field}"]`).forEach(el => {
      el.classList.toggle("d-none", !show)
    })
  }

  saveToStorage() {
    const visible = []
    const hidden = []

    this.fields.forEach(field => {
      if (this.visibleByField.get(field)) {
        visible.push(field)
      } else {
        hidden.push(field)
      }
    })

    localStorage.setItem(this.storageKeyValue, JSON.stringify({ visible, hidden }))
  }

  readStorage() {
    const raw = localStorage.getItem(this.storageKeyValue)
    if (raw === null) return null

    try {
      const parsed = JSON.parse(raw)
      if (!parsed || !Array.isArray(parsed.visible) || !Array.isArray(parsed.hidden)) return null

      return parsed
    } catch (e) {
      return null
    }
  }
}

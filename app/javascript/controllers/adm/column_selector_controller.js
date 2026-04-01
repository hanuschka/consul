import { Controller } from "@hotwired/stimulus"

// Column visibility toggle for kern-table.
// Reads th[data-field] headers, builds checkboxes, persists selection in a cookie.
export default class extends Controller {
  static values = {
    cookie: String,
    defaults: String // comma-separated default visible columns
  }

  static targets = ["table", "menu", "list"]

  connect() {
    this.buildCheckboxes()
    this.applyFromCookie()
  }

  toggle() {
    this.menuTarget.classList.toggle("adm-column-selector__menu--open")
  }

  close(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.remove("adm-column-selector__menu--open")
    }
  }

  // Build checkboxes from table headers that have data-field
  buildCheckboxes() {
    const headers = this.tableTarget.querySelectorAll("thead th[data-field]")
    this.fields = []

    headers.forEach(header => {
      const field = header.dataset.field || header.closest("[data-field]")?.dataset.field
      if (!field) return

      const text = header.textContent.trim()
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
    })
  }

  applyFromCookie() {
    let value = this.getCookie(this.cookieValue)
    if (!value) {
      value = this.defaultsValue
      this.setCookie(this.cookieValue, value)
    }

    const visible = value.split(",")

    this.fields.forEach(field => {
      const show = visible.includes(field)
      this.setColumnVisibility(field, show)

      const checkbox = this.listTarget.querySelector(`input[data-field="${field}"]`)
      if (checkbox) checkbox.checked = show
    })
  }

  toggleColumn(field, show) {
    this.setColumnVisibility(field, show)
    this.saveToCookie()
  }

  setColumnVisibility(field, show) {
    this.tableTarget.querySelectorAll(`[data-field="${field}"]`).forEach(el => {
      el.classList.toggle("d-none", !show)
    })
  }

  saveToCookie() {
    const checked = this.listTarget.querySelectorAll("input:checked")
    const value = Array.from(checked).map(cb => cb.dataset.field).join(",")
    this.setCookie(this.cookieValue, value)
  }

  getCookie(name) {
    const match = document.cookie.match(new RegExp("(^| )" + name + "=([^;]+)"))
    return match ? decodeURIComponent(match[2]) : ""
  }

  setCookie(name, value) {
    const date = new Date()
    date.setTime(date.getTime() + 30 * 24 * 60 * 60 * 1000) // 30 days
    document.cookie = `${name}=${encodeURIComponent(value)};expires=${date.toUTCString()};path=/`
  }
}

import { Controller } from "@hotwired/stimulus"

// Sends the WhatsApp test message without leaving the page and renders the raw
// transport result (HTTP status, request URL, response body) returned by the
// server, so a failing send can be diagnosed from the admin UI.
export default class extends Controller {
  static targets = ["phone", "submit", "result"]

  static values = {
    url: String,
    pendingTitle: String
  }

  async send(event) {
    event.preventDefault()

    this.submitTarget.disabled = true
    this.renderAlert("info", this.pendingTitleValue, {})

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ test: { phone: this.phoneTarget.value } })
      })

      if (!response.ok) {
        this.renderAlert("danger", `HTTP ${response.status} ${response.statusText}`, {})
        return
      }

      const result = await response.json()
      this.renderAlert(result.ok ? "success" : "danger", result.message, result.details)
    } catch (error) {
      this.renderAlert("danger", `${error.name}: ${error.message}`, {})
    } finally {
      this.submitTarget.disabled = false
    }
  }

  renderAlert(style, title, details) {
    this.resultTarget.replaceChildren(this.buildAlert(style, title, details))
  }

  buildAlert(style, title, details) {
    const alert = document.createElement("div")
    alert.className = `kern-alert kern-alert--${style}`
    alert.setAttribute("role", "alert")

    const header = document.createElement("div")
    header.className = "kern-alert__header"

    const icon = document.createElement("span")
    icon.className = `kern-icon kern-icon--${style}`
    icon.setAttribute("aria-hidden", "true")

    const titleElement = document.createElement("span")
    titleElement.className = "kern-title"
    titleElement.textContent = title

    header.append(icon, titleElement)
    alert.append(header)

    const entries = Object.entries(details || {}).filter(([, value]) => value !== "")

    if (entries.length > 0) {
      const body = document.createElement("div")
      body.className = "kern-alert__body"
      body.append(this.buildDetailsList(entries))
      alert.append(body)
    }

    return alert
  }

  buildDetailsList(entries) {
    const list = document.createElement("dl")
    list.className = "kern-description-list kern-description-list--col"

    entries.forEach(([label, value]) => {
      const item = document.createElement("div")
      item.className = "kern-description-list-item"

      const key = document.createElement("dt")
      key.className = "kern-description-list-item__key"
      key.textContent = label

      const detail = document.createElement("dd")
      detail.className = "kern-description-list-item__value adm-whatsapp-page--result-value"
      detail.textContent = value

      item.append(key, detail)
      list.append(item)
    })

    return list
  }

  csrfToken() {
    const element = document.querySelector("meta[name='csrf-token']")

    return element ? element.content : ""
  }
}

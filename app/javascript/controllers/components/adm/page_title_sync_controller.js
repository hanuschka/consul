import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    titleSelector: { type: String, default: "#adm-page-title" },
    breadcrumbSelector: { type: String, default: "#breadcrumb-projekt-name" }
  }

  sync(event) {
    if (!event.detail.success) return

    const input = this.element.querySelector("input[type='text']")
    if (!input) return

    const newTitle = input.value
    if (!newTitle) return

    const titleEl = document.querySelector(this.titleSelectorValue)
    if (titleEl) titleEl.textContent = newTitle

    const breadcrumbEl = document.querySelector(this.breadcrumbSelectorValue)
    if (breadcrumbEl) {
      const span = breadcrumbEl.querySelector("span")
      if (span) span.textContent = newTitle
    }
  }
}

import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

// Stimulus controller for the recipient-group filter stack on the
// adm recipient group edit page. Wraps:
//   - drag-sort persistence (via sortablejs)
//   - per-field debounced recount
//   - turbo-stream-driven filter updates and replacement
//
// Wired in:
//   app/views/adm/recipient_groups/edit.html.erb
//
// Companion templates:
//   app/views/adm/recipient_group_filters/*.turbo_stream.erb
export default class extends Controller {
  static targets = ["list"]
  static values = {
    recountUrl: String,
    reorderUrl: String,
    debounceMs: { type: Number, default: 400 }
  }

  connect() {
    if (this.hasListTarget) {
      this.sortable = Sortable.create(this.listTarget, {
        handle: ".rg-filter-card__handle",
        animation: 150,
        onEnd: () => this.persistOrder()
      })
    }
    this.recountTimer = null
  }

  disconnect() {
    this.sortable?.destroy()
    if (this.recountTimer) {
      clearTimeout(this.recountTimer)
    }
  }

  // Called when an inline filter control (operator/kind select) changes.
  // PATCHes the single filter, then schedules a recount.
  updateFilter(event) {
    const card = event.target.closest(".rg-filter-card")
    if (!card) return

    const filterId = card.dataset.filterId
    if (!filterId) return

    const target = event.target
    const formData = new FormData()

    if (target.type === "checkbox") {
      // Checkbox: send the value when checked, empty when unchecked.
      // event.target.value is the HTML value attribute (e.g. "1"), independent of checked state.
      formData.append(target.name, target.checked ? target.value : "")
    } else if (target.tagName === "SELECT" && target.multiple) {
      // Multi-select: send each selected option (or one empty marker if none).
      const selected = Array.from(target.selectedOptions).map((o) => o.value)
      if (selected.length === 0) {
        formData.append(target.name, "")
      } else {
        selected.forEach((v) => formData.append(target.name, v))
      }
    } else {
      formData.append(target.name, target.value)
    }

    const updateUrl = this.filterUrl(filterId)

    fetch(updateUrl, {
      method: "PATCH",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken()
      },
      body: formData
    })
      .then((response) => response.text())
      .then((html) => window.Turbo?.renderStreamMessage(html))
      .then(() => this.recount())
      .catch((error) => console.error("Filter update failed", error))
  }

  // Public entry-point for kind-specific param inputs.
  // Debounces the GET /recount call to avoid spamming the server.
  recount() {
    if (this.recountTimer) {
      clearTimeout(this.recountTimer)
    }
    this.recountTimer = setTimeout(() => this.fetchRecount(), this.debounceMsValue)
  }

  fetchRecount() {
    if (!this.recountUrlValue) return

    fetch(this.recountUrlValue, {
      headers: { Accept: "text/vnd.turbo-stream.html" }
    })
      .then((response) => response.text())
      .then((html) => window.Turbo?.renderStreamMessage(html))
      .catch((error) => console.error("Recount failed", error))
  }

  // Persist the visual sort order on the server. Triggered by sortablejs
  // when the user finishes a drag.
  persistOrder() {
    if (!this.reorderUrlValue) return

    const ids = Array.from(this.listTarget.querySelectorAll(".rg-filter-card"))
      .map((card) => card.dataset.filterId)
      .filter(Boolean)

    const formData = new FormData()
    ids.forEach((id) => formData.append("ordered_ids[]", id))

    fetch(this.reorderUrlValue, {
      method: "POST",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken()
      },
      body: formData
    })
      .then((response) => response.text())
      .then((html) => window.Turbo?.renderStreamMessage(html))
      .then(() => this.recount())
      .catch((error) => console.error("Reorder failed", error))
  }

  // Helpers

  filterUrl(filterId) {
    // recountUrlValue ends with "/recount" — strip that to reach the filter collection,
    // then append the filter id for the member route.
    return `${this.recountUrlValue.replace(/\/recount$/, "")}/${filterId}`
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

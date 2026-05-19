import { Controller } from "@hotwired/stimulus"

// Hides the notice on dismiss, persists dismissal in localStorage keyed by
// a hash of the message content. When the admin changes the message, a new
// hash means past dismissals don't apply — the notice fires fresh.
export default class extends Controller {
  static values = { storageKey: String }

  connect() {
    if (this.isDismissed()) this.element.style.display = "none"
  }

  dismiss() {
    this.element.style.display = "none"
    localStorage.setItem(this.storageKeyValue, "true")
  }

  isDismissed() {
    return localStorage.getItem(this.storageKeyValue) === "true"
  }
}

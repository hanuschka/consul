import { Controller } from "@hotwired/stimulus"

// Stimulus controller for inline auto-save of the recipient-group name on
// the adm edit page. PATCHes the name on input blur (or Enter/submit) and
// shows a small status message next to the field.
//
// Wired in:
//   app/views/adm/recipient_groups/edit.html.erb
//
// All user-facing strings are passed in via *-text-value data attributes —
// the controller never translates client-side.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = {
    url: String,
    savedText: String,
    errorText: String,
    clearAfterMs: { type: Number, default: 2500 }
  }

  connect() {
    this.lastSavedValue = this.hasInputTarget ? this.inputTarget.value : ""
    this.clearTimer = null
  }

  disconnect() {
    if (this.clearTimer) {
      clearTimeout(this.clearTimer)
      this.clearTimer = null
    }
  }

  save(event) {
    if (event) {
      event.preventDefault()
    }
    if (!this.hasInputTarget || !this.urlValue) return

    const value = this.inputTarget.value
    if (value === this.lastSavedValue) return

    const formData = new FormData()
    formData.append("recipient_group[name]", value)

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: formData
    })
      .then((response) => {
        if (response.ok) {
          this.lastSavedValue = value
          this.showStatus(this.savedTextValue, false)
        } else {
          this.showStatus(this.errorTextValue, true)
        }
      })
      .catch(() => {
        this.showStatus(this.errorTextValue, true)
      })
  }

  showStatus(text, isError) {
    if (!this.hasStatusTarget) return

    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("adm-name-autosave-status--error", Boolean(isError))
    this.statusTarget.classList.toggle("adm-name-autosave-status--success", !isError)

    if (this.clearTimer) {
      clearTimeout(this.clearTimer)
      this.clearTimer = null
    }
    if (!isError && this.clearAfterMsValue > 0) {
      this.clearTimer = setTimeout(() => {
        this.statusTarget.textContent = ""
        this.statusTarget.classList.remove("adm-name-autosave-status--success")
      }, this.clearAfterMsValue)
    }
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}

import { Controller } from "@hotwired/stimulus"

// Auto-saves the import review form whenever a field changes, so edits made
// before "create the projekt now" survive leaving the page. Every save PATCHes
// the FULL form state to the review's update URL (the form itself posts to the
// execute URL), debounced so a burst of edits becomes one request and
// serialized so the last write wins. A status line under the actions reports
// saving / saved / error.
//
// Wired in:
//   app/views/adm/projekts/imports/reviews/show.html.erb
//
// All user-facing strings arrive via *-text-value data attributes — the
// controller never translates client-side.
export default class extends Controller {
  static targets = ["status"]
  static values = {
    url: String,
    savingText: String,
    savedText: String,
    errorText: String,
    delay: { type: Number, default: 400 },
    clearAfterMs: { type: Number, default: 2500 }
  }

  connect() {
    this.saving = false
    this.rerun = false
    this.timer = null
    this.clearTimer = null
  }

  disconnect() {
    this.cancelPending()
    this.cancelClear()
  }

  save() {
    this.showStatus(this.savingTextValue, "saving")
    this.cancelPending()
    this.timer = setTimeout(() => this.persist(), this.delayValue)
  }

  persist() {
    if (this.saving) {
      this.rerun = true
      return
    }

    this.saving = true

    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: new FormData(this.element)
    })
      .then((response) => {
        if (response.ok) {
          this.showStatus(this.savedTextValue, "saved")
        } else {
          this.showStatus(this.errorTextValue, "error")
        }
      })
      .catch(() => {
        this.showStatus(this.errorTextValue, "error")
      })
      .finally(() => {
        this.saving = false

        if (this.rerun) {
          this.rerun = false
          this.persist()
        }
      })
  }

  showStatus(text, state) {
    if (!this.hasStatusTarget) return

    this.cancelClear()
    this.statusTarget.textContent = text
    this.statusTarget.classList.toggle("adm-name-autosave-status--success", state === "saved")
    this.statusTarget.classList.toggle("adm-name-autosave-status--error", state === "error")

    if (state === "saved" && this.clearAfterMsValue > 0) {
      this.clearTimer = setTimeout(() => {
        this.statusTarget.textContent = ""
        this.statusTarget.classList.remove("adm-name-autosave-status--success")
      }, this.clearAfterMsValue)
    }
  }

  cancelPending() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  cancelClear() {
    if (this.clearTimer) {
      clearTimeout(this.clearTimer)
      this.clearTimer = null
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}

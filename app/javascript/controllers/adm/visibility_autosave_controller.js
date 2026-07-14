import { Controller } from "@hotwired/stimulus"

// Auto-saves the evaluation-visibility form whenever a switch changes, so the
// page needs no submit button. Every save PATCHes the FULL form state (the
// backend treats an absent field as "off"), so a single toggle never wipes the
// others. Rapid toggles are debounced into one request, and saves are
// serialized so the last write wins. Each toggled row shows an inline spinner
// while saving and a checkmark (or error mark) when the request settles.
//
// Wired in:
//   app/views/adm/projekts/projekts/evaluation_visibility.html.erb
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 350 },
    clearAfterMs: { type: Number, default: 2000 }
  }

  connect() {
    this.pendingStatuses = new Set()
    this.saving = false
    this.rerun = false
  }

  disconnect() {
    this.cancelPending()
  }

  save(event) {
    const status = this.statusFor(event.target)
    if (status) {
      this.markStatus(status, "saving")
      this.pendingStatuses.add(status)
    }

    this.scheduleSave()
  }

  scheduleSave() {
    this.cancelPending()
    this.timer = setTimeout(() => this.persist(), this.delayValue)
  }

  persist() {
    if (this.saving) {
      this.rerun = true
      return
    }

    this.saving = true

    const statuses = [...this.pendingStatuses]
    this.pendingStatuses.clear()

    fetch(this.element.action, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken()
      },
      credentials: "same-origin",
      body: new FormData(this.element)
    })
      .then((response) => {
        const state = response.ok ? "saved" : "error"
        statuses.forEach((status) => this.markStatus(status, state))
      })
      .catch(() => {
        statuses.forEach((status) => this.markStatus(status, "error"))
      })
      .finally(() => {
        this.saving = false

        if (this.rerun) {
          this.rerun = false
          this.persist()
        }
      })
  }

  markStatus(status, state) {
    status.classList.remove("-saving", "-saved", "-error")
    status.classList.add(`-${state}`)

    if (state === "saved" && this.clearAfterMsValue > 0) {
      setTimeout(() => status.classList.remove("-saved"), this.clearAfterMsValue)
    }
  }

  statusFor(input) {
    const row = input.closest(".evaluation-visibility-row")
    return row ? row.querySelector(".evaluation-visibility-row__status") : null
  }

  cancelPending() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ""
  }
}

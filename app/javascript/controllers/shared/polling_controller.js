import { Controller } from "@hotwired/stimulus"

// Generic polling controller.
//
// Polls a JSON endpoint at a fixed interval, inspects a field of the response,
// and either reloads the page or fires a custom event when the field's value
// matches one of the configured terminal states. Stops polling on disconnect,
// on the first terminal hit, or after a configurable maximum number of attempts.
//
// HTML hook:
//   data-controller="shared--polling"
//   data-shared--polling-url-value="/path/to/status.json"
//   data-shared--polling-interval-value="4000"           (optional, default 4000ms)
//   data-shared--polling-status-field-value="status"     (optional, default "status")
//   data-shared--polling-terminal-states-value="completed failed"  (optional, space-separated)
//   data-shared--polling-on-terminal-value="reload"      (optional: "reload" | "event" | "redirect")
//   data-shared--polling-redirect-field-value="redirect_url" (optional, for "redirect")
//   data-shared--polling-max-attempts-value="450"        (optional, 0 = unlimited)
//
// When on-terminal="event", a `shared--polling:terminal` event is dispatched
// from the controller element with `detail: { status, data }`.
//
// When on-terminal="redirect", the browser navigates to the URL the payload
// carries in the redirect field — which lets the server hand back a URL that
// renders a flash message, something a plain reload cannot do. Falls back to a
// reload when the payload carries no URL.
export default class extends Controller {
  static values = {
    url: String,
    interval: { type: Number, default: 4000 },
    statusField: { type: String, default: "status" },
    terminalStates: { type: String, default: "completed failed" },
    onTerminal: { type: String, default: "reload" },
    redirectField: { type: String, default: "redirect_url" },
    maxAttempts: { type: Number, default: 0 }
  }

  connect() {
    if (this.urlValue.length === 0) return

    this.attempts = 0
    this.schedule()
  }

  disconnect() {
    this.clearTimer()
  }

  schedule() {
    this.clearTimer()
    this.timer = setTimeout(() => this.poll(), this.intervalValue)
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  poll() {
    this.attempts += 1

    if (this.maxAttemptsValue > 0 && this.attempts > this.maxAttemptsValue) {
      this.clearTimer()
      return
    }

    fetch(this.urlValue, {
      headers: { Accept: "application/json" },
      credentials: "same-origin"
    })
      .then((response) => this.handleResponse(response))
      .catch(() => this.schedule())
  }

  handleResponse(response) {
    if (!response.ok) {
      this.schedule()
      return
    }

    response.json()
      .then((data) => this.evaluate(data))
      .catch(() => this.schedule())
  }

  evaluate(data) {
    const status = data[this.statusFieldValue]
    const terminals = this.terminalStatesValue.split(/\s+/).filter(Boolean)

    if (terminals.includes(status)) {
      this.clearTimer()
      this.terminate(status, data)
      return
    }

    this.schedule()
  }

  terminate(status, data) {
    const redirectUrl = data[this.redirectFieldValue]

    if (this.onTerminalValue === "redirect" && redirectUrl) {
      window.location.assign(redirectUrl)
      return
    }

    if (this.onTerminalValue === "event") {
      this.dispatch("terminal", { detail: { status, data } })
      return
    }

    window.location.reload()
  }
}

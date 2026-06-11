import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    statusUrl: String,
    deleteUrl: String,
    interval: { type: Number, default: 5000 },
    timeout: { type: Number, default: 420000 }
  }

  connect() {
    this.startedAt = Date.now()
    this.scheduleNextPoll()
  }

  disconnect() {
    this.clearTimer()
  }

  scheduleNextPoll() {
    this.clearTimer()
    this.timer = setTimeout(() => this.poll(), this.intervalValue)
  }

  clearTimer() {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
  }

  isTimedOut() {
    return Date.now() - this.startedAt >= this.timeoutValue
  }

  poll() {
    if (this.isTimedOut()) {
      this.handleTimeout()
      return
    }

    fetch(this.statusUrlValue, {
      headers: { Accept: "text/vnd.turbo-stream.html" },
      credentials: "same-origin"
    })
      .then((response) => this.handleResponse(response))
      .catch(() => this.scheduleNextPoll())
  }

  handleResponse(response) {
    if (!response.ok) {
      this.scheduleNextPoll()
      return
    }

    response.text().then((html) => {
      const hasTerminalStream = this.containsRemoveForSelf(html)

      if (hasTerminalStream) {
        this.clearTimer()
        Turbo.renderStreamMessage(html)
        return
      }

      this.scheduleNextPoll()
    })
  }

  containsRemoveForSelf(html) {
    return html.includes(`target="${this.element.id}"`)
  }

  removeSelf() {
    this.clearTimer()
    this.element.remove()
  }

  handleTimeout() {
    this.clearTimer()

    if (!this.hasDeleteUrlValue) {
      this.element.remove()
      return
    }

    const csrfToken = document.querySelector("meta[name='csrf-token']")

    fetch(this.deleteUrlValue, {
      method: "DELETE",
      headers: {
        Accept: "text/vnd.turbo-stream.html",
        "X-CSRF-Token": csrfToken ? csrfToken.content : ""
      },
      credentials: "same-origin"
    })
      .then((response) => {
        if (!response.ok) {
          this.element.remove()
          return
        }

        response.text().then((html) => Turbo.renderStreamMessage(html))
      })
      .catch(() => this.element.remove())
  }
}

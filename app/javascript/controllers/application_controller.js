import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  fetchTurboStream(url, options = {}) {
    return fetch(url, {
      method: options.method || "GET",
      headers: {
        "Accept": "text/vnd.turbo-stream.html",
        "X-CSRF-Token": this.csrfToken
      }
    })
      .then(response => response.text())
      .then(html => Turbo.renderStreamMessage(html))
  }
}

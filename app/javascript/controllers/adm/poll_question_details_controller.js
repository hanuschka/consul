import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["participation", "crossectional"]
  static values = { url: String, loaded: Boolean }

  load() {
    if (this.loadedValue) return
    if (this.loadingPromise) return

    this.loadingPromise = fetch(this.urlValue, {
      headers: { Accept: "text/html" },
      credentials: "same-origin"
    })
      .then((response) => response.text())
      .then((html) => {
        this.inject(html)
        this.loadedValue = true
      })
      .catch(() => {
        this.showError()
        this.loadingPromise = null
      })
  }

  inject(html) {
    const template = document.createElement("template")
    template.innerHTML = html

    const participation = template.content.querySelector('[data-section="participation"]')
    const crossectional = template.content.querySelector('[data-section="crossectional"]')

    if (participation) this.participationTarget.innerHTML = participation.innerHTML
    if (crossectional) this.crossectionalTarget.innerHTML = crossectional.innerHTML
  }

  showError() {
    const message = '<div class="answer-detail-empty">—</div>'

    this.participationTarget.innerHTML = message
    this.crossectionalTarget.innerHTML = message
  }
}

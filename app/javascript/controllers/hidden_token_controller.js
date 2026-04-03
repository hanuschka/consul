import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "toggleBtn", "toggleIcon", "copyBtn"]
  static values = { token: String, showTitle: String, hideTitle: String }

  connect() {
    this.isVisible = false
    this.originalCopyHtml = this.copyBtnTarget.innerHTML
    this.copyTimeoutId = null
  }

  toggle(event) {
    event.preventDefault()
    this.isVisible = !this.isVisible

    if (this.isVisible) {
      this.displayTarget.textContent = this.tokenValue
      this.toggleBtnTarget.setAttribute("title", this.hideTitleValue)
      this.toggleIconTarget.textContent = "visibility_off"
    } else {
      this.displayTarget.textContent = "••••••••••••••••"
      this.toggleBtnTarget.setAttribute("title", this.showTitleValue)
      this.toggleIconTarget.textContent = "visibility"
    }
  }

  copy(event) {
    event.preventDefault()

    if (this.copyTimeoutId) {
      clearTimeout(this.copyTimeoutId)
    }

    navigator.clipboard.writeText(this.tokenValue).then(() => {
      this.copyBtnTarget.innerHTML =
        '<span class="material-symbols-outlined" aria-hidden="true" style="font-size: 18px;">check</span>'

      this.copyTimeoutId = setTimeout(() => {
        this.copyBtnTarget.innerHTML = this.originalCopyHtml
        this.copyTimeoutId = null
      }, 2000)
    })
  }
}

import { Controller } from "@hotwired/stimulus"

const COPIED_CLASS = "-copied"
const COPIED_RESET_DELAY = 1500

export default class extends Controller {
  static targets = ["source"]

  disconnect() {
    clearTimeout(this.resetTimeout)
  }

  copy(event) {
    event.preventDefault()
    navigator.clipboard.writeText(this.sourceTarget.innerHTML.trim())
    this.flagCopied()
  }

  flagCopied() {
    this.element.classList.add(COPIED_CLASS)

    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => this.element.classList.remove(COPIED_CLASS), COPIED_RESET_DELAY)
  }
}

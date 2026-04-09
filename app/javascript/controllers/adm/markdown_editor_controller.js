import { Controller } from "@hotwired/stimulus"
import markdownit from "markdown-it"

// Admin-only controller — preview uses innerHTML with html:true markdown-it config.
// Do not reuse in user-facing contexts without sanitization.
export default class extends Controller {
  static targets = ["textarea", "preview"]

  connect() {
    this.md = markdownit({ html: true, breaks: true, typographer: true })
    this.boundEscapeHandler = this.handleKeydown.bind(this)
    document.addEventListener("keydown", this.boundEscapeHandler)
    this.render()
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundEscapeHandler)
  }

  render() {
    const value = this.textareaTarget.value.trim()

    if (value) {
      this.previewTarget.innerHTML = this.md.render(value)
      this.previewTarget.classList.remove("adm-markdown-editor__preview--empty")
    } else {
      this.previewTarget.textContent = this.previewTarget.dataset.emptyText || ""
      this.previewTarget.classList.add("adm-markdown-editor__preview--empty")
    }
  }

  syncScroll() {
    this.previewTarget.scrollTop = this.textareaTarget.scrollTop
  }

  toggleFullscreen() {
    this.element.classList.toggle("adm-markdown-editor--fullscreen")

    if (this.element.classList.contains("adm-markdown-editor--fullscreen")) {
      this.textareaTarget.style.height = `${window.innerHeight - 120}px`
    } else {
      this.textareaTarget.style.height = ""
    }

    this.render()
  }

  handleKeydown(event) {
    if (event.key === "Escape" && this.element.classList.contains("adm-markdown-editor--fullscreen")) {
      this.toggleFullscreen()
    }
  }
}

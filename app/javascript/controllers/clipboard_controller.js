import { Controller } from "@hotwired/stimulus"

const COPIED_CLASS = "-copied"
const COPIED_RESET_DELAY = 1500

export default class extends Controller {
  static targets = ["source", "htmlSource"]

  disconnect() {
    clearTimeout(this.resetTimeout)
  }

  copy(event) {
    event.preventDefault()

    if (this.hasHtmlSourceTarget) {
      this.writeRichAndPlain()
    } else {
      this.writePlain()
    }

    this.flagCopied()
  }

  // textContent, not innerHTML: a plain source is a rendered element, so its
  // text sits there HTML-escaped and an & or a < would reach the clipboard as
  // an entity.
  writePlain() {
    navigator.clipboard.writeText(this.sourceTarget.textContent.trim())
  }

  // writeText can only ever produce text/plain, so an HTML source has to go
  // through a ClipboardItem: a CKEditor then consumes the text/html flavour
  // and keeps the formatting, while plain targets still get readable text.
  // The markup is the contract -- htmlSource is a <template>, whose contents
  // innerHTML serialises and whose fragment carries the plain flavour, so the
  // answer travels through the page only once.
  writeRichAndPlain() {
    const html = this.htmlSourceTarget.innerHTML.trim()
    const text = this.htmlSourceTarget.content.textContent.replace(/\s+/g, " ").trim()

    if (!window.ClipboardItem || !navigator.clipboard.write) {
      navigator.clipboard.writeText(text)
      return
    }

    navigator.clipboard.write([
      new ClipboardItem({
        "text/html": new Blob([html], { type: "text/html" }),
        "text/plain": new Blob([text], { type: "text/plain" })
      })
    ]).catch(() => navigator.clipboard.writeText(text))
  }

  flagCopied() {
    this.element.classList.add(COPIED_CLASS)

    clearTimeout(this.resetTimeout)
    this.resetTimeout = setTimeout(() => this.element.classList.remove(COPIED_CLASS), COPIED_RESET_DELAY)
  }
}

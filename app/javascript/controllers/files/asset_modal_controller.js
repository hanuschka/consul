import { Controller } from "@hotwired/stimulus"

// Opens the asset detail page inside a native <dialog>. The card thumbnail is a
// real link (data-turbo-frame) pointing at the asset show route: a plain click
// lets Turbo load the response into the dialog's frame while we open the modal;
// a modifier/middle click falls through to the browser and opens the full page
// in a new tab.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  connect() {
    this.loadingHtml = this.hasFrameTarget ? this.frameTarget.innerHTML : ""
  }

  open(event) {
    if (this.isModifiedClick(event)) return
    if (!this.hasDialogTarget) return

    this.dialogTarget.showModal()
  }

  close() {
    if (this.hasDialogTarget) this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  onClose() {
    if (this.hasFrameTarget) this.frameTarget.innerHTML = this.loadingHtml
  }

  isModifiedClick(event) {
    return (
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey ||
      event.button === 1
    )
  }
}

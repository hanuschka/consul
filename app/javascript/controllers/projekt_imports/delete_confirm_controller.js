import { Controller } from "@hotwired/stimulus"

// Index-page delete confirmation. A row's delete button opens one shared modal,
// pre-filled with that import's name; the confirm button submits a DELETE to the
// import's URL. The server destroys only the import (the created projekt stays).
export default class extends Controller {
  static targets = ["dialog", "form", "label"]

  request(event) {
    const button = event.currentTarget
    this.formTarget.action = button.dataset.deleteUrl

    if (this.hasLabelTarget) this.labelTarget.textContent = button.dataset.importLabel || ""

    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}

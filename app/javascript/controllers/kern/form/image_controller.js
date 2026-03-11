import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "inputWrapper", "preview", "previewImage", "actions", "destroy"]
  static values = { autoSubmit: Boolean }

  change() {
    const file = this.inputTarget.files[0]
    if (!file) return

    if (this.hasDestroyTarget) {
      this.destroyTarget.value = "false"
    }

    if (this.autoSubmitValue) {
      this.element.closest("form").requestSubmit()
      return
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewImageTarget.src = e.target.result
      this.previewTarget.classList.remove("d-none")
      this.inputWrapperTarget.classList.add("d-none")
      this.actionsTarget.classList.remove("d-none")
    }
    reader.readAsDataURL(file)
  }

  remove() {
    if (this.hasDestroyTarget) {
      this.destroyTarget.value = "1"
    }
    this.inputTarget.value = ""
    this.previewTarget.classList.add("d-none")
    this.actionsTarget.classList.add("d-none")
    this.inputWrapperTarget.classList.remove("d-none")
  }
}

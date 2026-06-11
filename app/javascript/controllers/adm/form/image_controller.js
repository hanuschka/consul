import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="adm--form--image"
export default class extends Controller {
  static targets = ["input", "preview", "previewImage", "empty", "destroy"]

  triggerInput() {
    this.inputTarget.click()
  }

  change() {
    const file = this.inputTarget.files[0]
    if (!file) return

    if (this.hasDestroyTarget) {
      this.destroyTarget.value = "false"
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewImageTarget.src = e.target.result
      this.showPreview()
    }
    reader.readAsDataURL(file)
  }

  remove() {
    if (this.hasDestroyTarget) {
      this.destroyTarget.value = "1"
    }
    this.inputTarget.value = ""
    this.showEmpty()
  }

  showPreview() {
    this.previewTarget.classList.remove("d-none")
    this.emptyTarget.classList.add("d-none")
  }

  showEmpty() {
    this.previewTarget.classList.add("d-none")
    this.emptyTarget.classList.remove("d-none")
  }
}

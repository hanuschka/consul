import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "addButton", "error"]
  static values = {
    addUrl: String
  }

  showForm() {
    this.formTarget.classList.remove("d-none")
    this.addButtonTarget.classList.add("d-none")
    this.hideError()
  }

  hideForm() {
    this.formTarget.classList.add("d-none")
    this.addButtonTarget.classList.remove("d-none")
    this.formTarget.reset()
  }

  async submit(event) {
    event.preventDefault()

    const formData = new FormData(this.formTarget)
    const submitButton = this.formTarget.querySelector('button[type="submit"]')
    submitButton.disabled = true
    this.hideError()

    try {
      const response = await fetch(this.addUrlValue, {
        method: "POST",
        body: formData,
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        }
      })

      const text = await response.text()

      if (response.ok) {
        Turbo.renderStreamMessage(text)
      } else {
        this.showError(text)
      }
    } catch (error) {
      this.showError("Ein Fehler ist aufgetreten. Bitte versuchen Sie es erneut.")
    } finally {
      submitButton.disabled = false
    }
  }

  showError(message) {
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = message
      this.errorTarget.classList.remove("d-none")
    }
  }

  hideError() {
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add("d-none")
    }
  }
}

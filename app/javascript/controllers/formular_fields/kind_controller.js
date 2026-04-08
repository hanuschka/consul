import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdownFields", "emailFields", "confirmationFields"]

  connect() {
    this.toggle()
  }

  toggle() {
    const kind = this.element.querySelector("select").value

    this.dropdownFieldsTarget.style.display = kind === "dropdown" ? "block" : "none"
    this.emailFieldsTarget.style.display = kind === "email" ? "block" : "none"
  }

  toggleConfirmation(event) {
    this.confirmationFieldsTarget.style.display = event.target.checked ? "block" : "none"
  }
}

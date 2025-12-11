import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "successMessage", "errorMessage" ]

  connect() {
    if (this.hasInputTarget) { this.placeCursorAtEnd() }
    if (this.hasSuccessMessageTarget) { this.fadeOutSuccessMessage() }
  }

  placeCursorAtEnd() {
    if (this.hasSuccessMessageTarget || this.hasErrorMessageTarget) {
      const input = this.inputTarget;
      const length = input.value.length;
      input.focus();
      input.setSelectionRange(length, length);
    }
  }

  fadeOutSuccessMessage() {
    setTimeout(() => {
      this.successMessageTarget.style.opacity = '0';
      setTimeout(() => this.successMessageTarget.remove(), 500);
    }, 1000);
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "successMessage" ]
  static values = { updated: Boolean }

  connect() {
    if (!this.updatedValue) return;

    if (this.hasInputTarget) { this.placeCursorAtEnd() }
    this.fadeOutSuccessMessage();
  }

  placeCursorAtEnd() {
    const input = this.inputTarget;
    const length = input.value.length;
    input.setSelectionRange(length, length);
  }

  fadeOutSuccessMessage() {
    setTimeout(() => {
      this.successMessageTarget.style.opacity = '0';
      setTimeout(() => this.successMessageTarget.remove(), 500);
    }, 1000);
  }
}

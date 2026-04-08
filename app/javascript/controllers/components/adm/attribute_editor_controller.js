import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "input", "errorMessage" ]

  connect() {
    if (this.hasInputTarget) { this.placeCursorAtEnd() }
  }

  placeCursorAtEnd() {
    if (this.hasErrorMessageTarget) {
      const input = this.inputTarget;
      const length = input.value.length;
      input.focus();
      input.setSelectionRange(length, length);
    }
  }
}

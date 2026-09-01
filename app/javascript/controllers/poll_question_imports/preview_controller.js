import { Controller } from "@hotwired/stimulus"

// The title copy in each question card head of the import preview.
//
// One instance covers the whole preview rather than one per card -- a document
// can hold well over a hundred questions, and the title inputs and their head
// copies are both in card order, so they pair up by index.
//
// HTML hook:
//   data-controller="poll-question-imports--preview"
export default class extends Controller {
  static targets = ["titleInput", "titleOutput"]

  connect() {
    this.titleInputTargets.forEach((input, index) => this.writeTitle(input, index))
  }

  updateTitle(event) {
    const index = this.titleInputTargets.indexOf(event.target)
    if (index < 0) return

    this.writeTitle(event.target, index)
  }

  writeTitle(input, index) {
    const output = this.titleOutputTargets[index]
    if (!output) return

    output.textContent = input.value.trim()
  }
}

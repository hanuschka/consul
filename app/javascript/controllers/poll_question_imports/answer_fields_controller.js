import { Controller } from "@hotwired/stimulus"

// Add and remove answer rows on the import preview before the questions are
// saved. The blank row comes from a <template> the server rendered through the
// same partial as the existing rows, so only the index placeholders have to be
// filled in here.
//
// Indices are never renumbered on removal: the apply service reads the params
// hash by value rather than by position, so a gap in questions[i][answers][j]
// costs nothing and a removed row can never take another row's name with it.
export default class extends Controller {
  static targets = ["list", "template"]

  static values = { nextIndex: Number }

  add() {
    const index = this.nextIndexValue
    const markup = this.templateTarget.innerHTML
      .replaceAll("__ANSWER_INDEX__", index.toString())
      .replaceAll("__ANSWER_POSITION__", (index + 1).toString())

    this.listTarget.insertAdjacentHTML("beforeend", markup)
    this.nextIndexValue = index + 1

    this.listTarget.lastElementChild?.querySelector("input")?.focus()
  }

  remove(event) {
    event.currentTarget.closest(".adm-poll-question-answer")?.remove()
  }
}

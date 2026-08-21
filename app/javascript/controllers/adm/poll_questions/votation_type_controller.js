import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["maxVotes", "maxVotesPerAnswer", "ratingScaleLabels", "randomizeAnswers", "hint"]

  connect() {
    this.toggle()
  }

  toggle() {
    const voteType = this.element.querySelector("select").value

    this.maxVotesTarget.style.display =
      ["multiple", "multiple_with_weight"].includes(voteType) ? "block" : "none"

    this.maxVotesPerAnswerTarget.style.display =
      voteType === "multiple_with_weight" ? "block" : "none"

    this.ratingScaleLabelsTarget.style.display =
      voteType === "rating_scale" ? "block" : "none"

    this.randomizeAnswersTarget.style.display =
      voteType === "rating_scale" ? "none" : "block"

    if (voteType === "rating_scale") {
      this.randomizeAnswersTarget.querySelector("input[type=checkbox]").checked = false
    }

    this.hintTargets.forEach(hint => {
      hint.style.display = hint.dataset.voteType === voteType ? "block" : "none"
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["maxVotes", "maxVotesPerAnswer", "ratingScaleLabels", "hint"]

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

    this.hintTargets.forEach(hint => {
      hint.style.display = hint.dataset.voteType === voteType ? "block" : "none"
    })
  }
}

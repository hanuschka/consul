import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["maxVotes", "maxVotesPerAnswer", "ratingScaleLabels", "randomizeAnswers",
                    "maxMapPoints", "boundary", "hint"]

  connect() {
    this.toggle()
  }

  toggle() {
    const voteType = this.element.querySelector("select").value
    const mapPoints = voteType === "map_points"
    const ratingScale = voteType === "rating_scale"

    this.maxVotesTarget.style.display =
      ["multiple", "multiple_with_weight"].includes(voteType) ? "block" : "none"

    this.maxVotesPerAnswerTarget.style.display =
      voteType === "multiple_with_weight" ? "block" : "none"

    this.ratingScaleLabelsTarget.style.display = ratingScale ? "block" : "none"

    this.maxMapPointsTarget.style.display = mapPoints ? "block" : "none"
    this.boundaryTarget.style.display = mapPoints ? "block" : "none"

    this.setFieldsDisabled(this.maxVotesTarget, mapPoints)
    this.setFieldsDisabled(this.maxMapPointsTarget, !mapPoints)
    this.setFieldsDisabled(this.boundaryTarget, !mapPoints)

    this.randomizeAnswersTarget.style.display = ratingScale || mapPoints ? "none" : "block"

    if (ratingScale || mapPoints) {
      this.randomizeAnswersTarget.querySelector("input[type=checkbox]").checked = false
    }

    this.hintTargets.forEach(hint => {
      hint.style.display = hint.dataset.voteType === voteType ? "block" : "none"
    })
  }

  setFieldsDisabled(target, disabled) {
    target.querySelectorAll("input, select, textarea").forEach(field => {
      field.disabled = disabled
    })
  }
}

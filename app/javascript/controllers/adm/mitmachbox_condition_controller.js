import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "group"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.selectTarget.value

    this.groupTargets.forEach((group) => {
      const active = group.dataset.questionId === selected

      group.hidden = !active
      group.querySelectorAll("input").forEach((input) => {
        input.disabled = !active
      })
    })
  }
}

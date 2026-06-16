import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "bulk"]

  connect() {
    this.updateBulkLabel()
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.addEventListener("change", this.updateBulkLabel.bind(this))
    })
  }

  toggleAll(event) {
    event.preventDefault()
    const turnAllOn = !this.allChecked()
    this.checkboxTargets.forEach((checkbox) => {
      checkbox.checked = turnAllOn
    })
    this.updateBulkLabel()
  }

  updateBulkLabel() {
    if (!this.hasBulkTarget) return
    const button = this.bulkTarget
    const label = this.allChecked() ? button.dataset.onLabel : button.dataset.offLabel
    button.textContent = label
  }

  allChecked() {
    return this.checkboxTargets.every((checkbox) => checkbox.checked)
  }
}

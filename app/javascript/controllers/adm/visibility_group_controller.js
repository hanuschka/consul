import { Controller } from "@hotwired/stimulus"

const SUBGROUP_SELECTOR = ".evaluation-visibility-subgroup"
const CHECKBOX_SELECTOR = "[data-adm--visibility-group-target='checkbox']"

export default class extends Controller {
  static targets = ["checkbox", "bulk", "groupBulk"]

  connect() {
    this.updateLabels()
  }

  updateLabels() {
    if (this.hasBulkTarget) {
      this.applyLabel(this.bulkTarget, this.checkboxTargets)
    }

    this.groupBulkTargets.forEach((button) => {
      this.applyLabel(button, this.groupCheckboxes(button))
    })
  }

  toggleAll(event) {
    event.preventDefault()
    this.setChecked(this.checkboxTargets, !this.allChecked(this.checkboxTargets))
  }

  toggleGroup(event) {
    event.preventDefault()
    const checkboxes = this.groupCheckboxes(event.currentTarget)
    this.setChecked(checkboxes, !this.allChecked(checkboxes))
  }

  setChecked(checkboxes, turnAllOn) {
    checkboxes.forEach((checkbox) => {
      if (checkbox.checked === turnAllOn) return

      checkbox.checked = turnAllOn
      checkbox.dispatchEvent(new Event("change", { bubbles: true }))
    })
    this.updateLabels()
  }

  applyLabel(button, checkboxes) {
    button.textContent = this.allChecked(checkboxes) ? button.dataset.onLabel : button.dataset.offLabel
  }

  groupCheckboxes(button) {
    const subgroup = button.closest(SUBGROUP_SELECTOR)
    if (!subgroup) return []

    return Array.from(subgroup.querySelectorAll(CHECKBOX_SELECTOR))
  }

  allChecked(checkboxes) {
    return checkboxes.length > 0 && checkboxes.every((checkbox) => checkbox.checked)
  }
}

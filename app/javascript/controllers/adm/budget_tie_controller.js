import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = {
    freePlaces: Number,
    remainingBudget: Number
  }

  connect() {
    this.update()
  }

  update() {
    const ticked = this.checkboxTargets.filter((checkbox) => checkbox.checked)
    const placesFull = this.hasFreePlacesValue && ticked.length >= this.freePlacesValue
    const budgetLeft = this.hasRemainingBudgetValue
      ? this.remainingBudgetValue - ticked.reduce((sum, checkbox) => sum + this.priceOf(checkbox), 0)
      : null

    this.checkboxTargets.forEach((checkbox) => {
      if (checkbox.checked) {
        checkbox.disabled = false
        return
      }

      const tooExpensive = budgetLeft !== null && this.priceOf(checkbox) > budgetLeft
      checkbox.disabled = placesFull || tooExpensive
    })
  }

  priceOf(checkbox) {
    return Number(checkbox.dataset.price) || 0
  }
}

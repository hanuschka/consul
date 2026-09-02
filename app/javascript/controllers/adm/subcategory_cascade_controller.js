import { Controller } from "@hotwired/stimulus"

// Keeps the subcategory select in step with the chosen category: only that category's subcategories
// stay selectable, and the whole field disappears for a category that has none. Options are removed
// rather than hidden, because a hidden <option> is still selectable in several browsers.
export default class extends Controller {
  static targets = ["select", "wrapper"]

  connect() {
    // No targets at all when the client has not configured a single subcategory: the form renders
    // the category pills without a subcategory field, and there is nothing to keep in step.
    if (!this.hasSelectTarget) return

    this.allOptions = Array.from(this.selectTarget.options).map((option) => option.cloneNode(true))
    this.refresh()
  }

  refresh() {
    if (!this.hasSelectTarget) return

    const categoryId = this.currentCategoryId()
    const selected = this.selectTarget.value

    const matching = this.allOptions.filter((option) => {
      const optionCategory = option.dataset.categoryId
      return !optionCategory || optionCategory === String(categoryId)
    })

    this.selectTarget.replaceChildren(...matching.map((option) => option.cloneNode(true)))

    if (matching.some((option) => option.value === selected)) {
      this.selectTarget.value = selected
    }

    if (this.hasWrapperTarget) {
      this.wrapperTarget.hidden = !matching.some((option) => option.value !== "")
    }
  }

  currentCategoryId() {
    const checked = this.element.querySelector(
      "input[name='deficiency_report[deficiency_report_category_id]']:checked"
    )

    return checked ? checked.value : null
  }
}

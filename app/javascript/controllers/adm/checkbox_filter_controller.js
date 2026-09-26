import { Controller } from "@hotwired/stimulus"

// Client-side filter for a list of checkboxes too long to scan by eye. It only
// hides the items whose label does not match what was typed and never touches
// their checked state, so a selection scrolled out of sight -- or filtered away
// -- is still submitted with the form.
export default class extends Controller {
  static targets = ["input", "item", "empty", "count"]

  static values = {
    debounceDelay: { type: Number, default: 150 }
  }

  connect() {
    this.debounceTimer = null

    // The label of every item, read and normalised once: a pass over hundreds
    // of them happens per keystroke, and reading textContent there would make
    // each one a layout question again.
    this.searchableItems = this.itemTargets.map((element) => ({
      element,
      text: this.normalize(element.dataset.filterText || element.textContent)
    }))

    this.selectedCount = this.countCheckedBoxes()
    this.renderSelectedCount()
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  filter() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => this.applyFilter(), this.debounceDelayValue)
  }

  applyFilter() {
    const query = this.normalize(this.hasInputTarget ? this.inputTarget.value : "")
    let visibleCount = 0

    this.searchableItems.forEach((item) => {
      const matches = query.length === 0 || item.text.includes(query)

      item.element.hidden = !matches

      if (matches) visibleCount += 1
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visibleCount > 0
    }
  }

  // The box that fired tells how the total moved, so ticking one item off does
  // not walk the whole list again.
  refreshSelected(event) {
    const box = event && event.target

    if (box && box.type === "checkbox") {
      this.selectedCount += box.checked ? 1 : -1
    } else {
      this.selectedCount = this.countCheckedBoxes()
    }

    this.renderSelectedCount()
  }

  renderSelectedCount() {
    if (!this.hasCountTarget) return

    this.countTarget.textContent = this.selectedCount
  }

  countCheckedBoxes() {
    return this.element.querySelectorAll("input[type=checkbox]:checked").length
  }

  // Typed German rarely carries the umlauts of the name being looked for, so
  // both sides are compared without their diacritics.
  normalize(value) {
    return value
      .toString()
      .trim()
      .toLowerCase()
      .normalize("NFD")
      .replace(/\p{Diacritic}/gu, "")
  }
}

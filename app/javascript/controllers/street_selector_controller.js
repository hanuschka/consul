import ApplicationController from "./application_controller"

export default class extends ApplicationController {
  static targets = ["searchInput", "selectedStreets", "results", "checkboxes"]

  static values = {
    searchUrl: String,
    fieldName: String,
    debounceDelay: { type: Number, default: 300 },
    minChars: { type: Number, default: 2 }
  }

  connect() {
    this.debounceTimer = null
    this.handleClickOutside = this.handleClickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    document.removeEventListener("click", this.handleClickOutside)
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.clearResults()
      this.hideResults()
    }
  }

  search(event) {
    if (event.type === "keydown" && event.key === "Enter") {
      event.preventDefault()
    }

    const query = this.searchInputTarget.value.trim()

    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    this.debounceTimer = setTimeout(() => {
      this.performSearch(query)
    }, this.debounceDelayValue)
  }

  performSearch(query) {
    this.clearResults()
    this.hideResults()

    if (query.length < this.minCharsValue) return

    const url = new URL(this.searchUrlValue, window.location.origin)
    url.searchParams.set("query", query)

    this.selectedStreetIds.forEach(id => {
      url.searchParams.append("selected_ids[]", id)
    })

    this.fetchTurboStream(url.toString())
      .then(() => requestAnimationFrame(() => this.updateVisibility()))
  }

  addStreet(event) {
    const element = event.currentTarget
    const streetId = element.dataset.streetId
    const streetName = element.dataset.streetName

    this.appendSelectedStreet(streetId, streetName)
    this.appendCheckbox(streetId)
    element.remove()

    this.clearResults()
    this.hideResults()
    this.searchInputTarget.value = ""
  }

  removeStreet(event) {
    const streetId = event.currentTarget.dataset.streetId

    document.getElementById(`selected-street-${streetId}`)?.remove()
    document.getElementById(`street_checkbox_${streetId}`)?.remove()
  }

  // Private

  appendSelectedStreet(streetId, streetName) {
    const html = `
      <div class="selected-street" id="selected-street-${streetId}" data-street-id="${streetId}">
        ${this.escapeHtml(streetName)}
        <span class="material-symbols-outlined cursor-pointer" data-street-id="${streetId}" data-action="click->street-selector#removeStreet">close</span>
      </div>
    `
    this.selectedStreetsTarget.insertAdjacentHTML("beforeend", html)
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }

  appendCheckbox(streetId) {
    const html = `
      <input type="checkbox"
             name="${this.fieldNameValue}"
             value="${streetId}"
             checked
             id="street_checkbox_${streetId}">
    `
    this.checkboxesTarget.insertAdjacentHTML("beforeend", html)
  }

  get selectedStreetIds() {
    if (!this.hasCheckboxesTarget) return []

    return Array.from(this.checkboxesTarget.querySelectorAll("input[type='checkbox']:checked"))
      .map(checkbox => checkbox.value)
  }

  clearResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.innerHTML = ""
    }
  }

  updateVisibility() {
    if (this.hasResultsTarget && this.resultsTarget.children.length > 0) {
      this.showResults()
    } else {
      this.hideResults()
    }
  }

  showResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.remove("d-none")
    }
  }

  hideResults() {
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add("d-none")
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    placeholder: { type: String, default: "Filter..." }
  }

  connect() {
    this.items = this.element.querySelectorAll(".kern-form-check")
    this.ensureSearchInput()
  }

  ensureSearchInput() {
    if (this.element.querySelector("[data-select-filter-search]")) return
    if (this.items.length < 6) return

    const inputContainer = document.createElement("div")
    inputContainer.className = "kern-form-input"

    const input = document.createElement("input")
    input.type = "search"
    input.placeholder = this.placeholderValue
    input.className = "kern-form-input__input"
    input.setAttribute("data-select-filter-search", "")
    input.setAttribute("aria-label", "Filter options")

    input.addEventListener("input", this.filter.bind(this))
    input.addEventListener("keydown", (event) => {
      if (event.key === "Enter") {
        event.preventDefault()
      } else if (event.key === "Escape") {
        input.value = ""
        this.filter(event)
      }
    })

    inputContainer.appendChild(input)

    this.element.prepend(inputContainer)
  }

  filter(event) {
    const query = this.normalize(event.target.value)

    this.items.forEach((item) => {
      const label = item.querySelector("label")
      if (!label) return

      const text = this.normalize(label.textContent)

      item.style.display = this.matches(text, query) ? "" : "none"
    })
  }

  matches(text, query) {
    if (!query) return true
    return query
      .split(" ")
      .every((term) => text.includes(term))
  }

  normalize(text) {
    return text
      .toLowerCase()
      .normalize("NFD")
      .replace(/\p{Diacritic}/gu, "")
      .replace(/[^a-z0-9\s]/g, "")
      .replace(/\s+/g, " ")
      .trim()
  }
}

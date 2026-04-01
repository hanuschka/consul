import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list", "input", "template"]
  static values = {
    createUrl: String,
    reorderUrl: String,
    updateUrlTemplate: String,
    deleteUrlTemplate: String
  }

  connect() {
    this.initSortable()
    this.initInlineEdit()
  }

  initSortable() {
    Sortable.create(this.listTarget, {
      handle: "[data-criteria-handle]",
      animation: 150,
      onEnd: () => this.handleReorder()
    })
  }

  handleReorder() {
    const order = Array.from(this.listTarget.querySelectorAll("[data-criterion-id]"))
      .map((el) => el.dataset.criterionId)

    fetch(this.reorderUrlValue, {
      method: "PATCH",
      headers: this.headers(),
      body: JSON.stringify({ order })
    })
  }

  initInlineEdit() {
    this.element.addEventListener("click", (e) => {
      const textEl = e.target.closest("[data-criteria-text]")
      if (!textEl) return

      const currentText = textEl.textContent.trim()
      const input = document.createElement("input")
      input.type = "text"
      input.value = currentText
      input.className = "kern-form-input__input"

      input.addEventListener("blur", () => this.saveInlineEdit(input))
      input.addEventListener("keydown", (event) => {
        if (event.key === "Enter") {
          event.preventDefault()
          input.blur()
        }
      })

      textEl.replaceWith(input)
      input.focus()
    })
  }

  saveInlineEdit(input) {
    const item = input.closest("[data-criterion-id]")
    const url = this.updateUrlTemplate(item.dataset.criterionId)
    const text = input.value.trim()

    fetch(url, {
      method: "PATCH",
      headers: this.headers(),
      body: JSON.stringify({ user_resource_criterion: { text } })
    }).then(() => {
      const span = document.createElement("span")
      span.setAttribute("data-criteria-text", "")
      span.className = "kern-criteria-list__text"
      span.textContent = text
      input.replaceWith(span)
    })
  }

  addCriterion(e) {
    e.preventDefault()
    const text = this.inputTarget.value.trim()

    if (!text) return

    fetch(this.createUrlValue, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({ user_resource_criterion: { text } })
    })
      .then((response) => response.json())
      .then((data) => {
        this.appendCriterion(data)
        this.inputTarget.value = ""
      })
  }

  deleteCriterion(e) {
    e.preventDefault()
    const item = e.target.closest("[data-criterion-id]")
    const url = this.deleteUrlTemplate(item.dataset.criterionId)

    fetch(url, {
      method: "DELETE",
      headers: this.headers()
    }).then(() => item.remove())
  }

  appendCriterion(data) {
    const template = this.templateTarget.innerHTML
    const html = template
      .replace(/\{\{ id \}\}/g, data.id)
      .replace(/\{\{ text \}\}/g, data.text)

    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  updateUrlTemplate(id) {
    return this.updateUrlTemplateValue.replace("CRITERION_ID", id)
  }

  deleteUrlTemplate(id) {
    return this.deleteUrlTemplateValue.replace("CRITERION_ID", id)
  }

  headers() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
    }
  }
}

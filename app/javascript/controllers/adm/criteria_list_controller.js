import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

const EDITABLE_FIELDS = ["name", "description", "ai_instruction"]

export default class extends Controller {
  static targets = ["list", "inputName", "inputAiInstruction", "template"]
  static values = {
    kind: String,
    createUrl: String,
    reorderUrl: String,
    updateUrlTemplate: String,
    deleteUrlTemplate: String
  }

  connect() {
    this.initSortable()
    this.bindFieldEdits()
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
      body: JSON.stringify({ order, kind: this.kindValue })
    })
  }

  bindFieldEdits() {
    this.listTarget.addEventListener("change", (e) => this.handleFieldChange(e))
    this.listTarget.addEventListener("blur", (e) => this.handleFieldChange(e), true)
  }

  handleFieldChange(e) {
    const field = e.target.dataset.criteriaField

    if (!EDITABLE_FIELDS.includes(field)) return

    const item = e.target.closest("[data-criterion-id]")

    if (!item) return

    const id = item.dataset.criterionId
    const payload = { user_resource_criterion: {} }
    payload.user_resource_criterion[field] = e.target.value

    fetch(this.buildUpdateUrl(id), {
      method: "PATCH",
      headers: this.headers(),
      body: JSON.stringify(payload)
    })
  }

  addCriterion(e) {
    e.preventDefault()
    const name = this.inputNameTarget.value.trim()
    const aiInstruction = this.inputAiInstructionTarget.value.trim()

    if (!name || !aiInstruction) return

    fetch(this.createUrlValue, {
      method: "POST",
      headers: this.headers(),
      body: JSON.stringify({
        kind: this.kindValue,
        user_resource_criterion: { name, ai_instruction: aiInstruction }
      })
    })
      .then((response) => response.json())
      .then((data) => this.handleCreated(data))
  }

  handleCreated(data) {
    this.appendCriterion(data)
    this.inputNameTarget.value = ""
    this.inputAiInstructionTarget.value = ""
  }

  deleteCriterion(e) {
    e.preventDefault()
    const item = e.target.closest("[data-criterion-id]")

    fetch(this.buildDeleteUrl(item.dataset.criterionId), {
      method: "DELETE",
      headers: this.headers()
    }).then(() => item.remove())
  }

  appendCriterion(data) {
    const template = this.templateTarget.innerHTML
    const html = template
      .replace(/\{\{\s*id\s*\}\}/g, data.id)
      .replace(/\{\{\s*name\s*\}\}/g, this.escape(data.name))
      .replace(/\{\{\s*description\s*\}\}/g, this.escape(data.description || ""))
      .replace(/\{\{\s*ai_instruction\s*\}\}/g, this.escape(data.ai_instruction || ""))

    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  escape(value) {
    const div = document.createElement("div")
    div.textContent = value

    return div.innerHTML
  }

  buildUpdateUrl(id) {
    return this.updateUrlTemplateValue.replace("CRITERION_ID", id)
  }

  buildDeleteUrl(id) {
    return this.deleteUrlTemplateValue.replace("CRITERION_ID", id)
  }

  headers() {
    return {
      "Content-Type": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
    }
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entries", "template", "addButton", "entry"]
  static values = { max: Number }

  add() {
    const content = this.templateTarget.content.cloneNode(true)
    const timestamp = Date.now()

    content.querySelectorAll("[name], [id], [for]").forEach((el) => {
      if (el.name) el.name = el.name.replace(/NEW_RECORD/g, timestamp)
      if (el.id) el.id = el.id.replace(/NEW_RECORD/g, timestamp)
      if (el.htmlFor) el.htmlFor = el.htmlFor.replace(/NEW_RECORD/g, timestamp)
    })

    this.entriesTarget.appendChild(content)
    this.updateAddButton()
  }

  remove(event) {
    const entry = event.target.closest("[data-kern--form--documents-target='entry']")
    const destroyField = entry.querySelector("[data-kern--form--documents-target='destroy']")

    if (destroyField) {
      destroyField.value = "1"
      entry.classList.add("d-none")
    } else {
      entry.remove()
    }

    this.updateAddButton()
  }

  updateAddButton() {
    const visibleCount = this.entryTargets.filter((entry) => !entry.classList.contains("d-none")).length

    if (visibleCount >= this.maxValue) {
      this.addButtonTarget.classList.add("d-none")
    } else {
      this.addButtonTarget.classList.remove("d-none")
    }
  }
}

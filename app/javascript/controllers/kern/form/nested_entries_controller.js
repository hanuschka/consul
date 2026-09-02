import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["entries", "template", "addButton", "entry", "destroy"]
  static values = { max: { type: Number, default: 10 } }

  connect() {
    this.updateAddButton()
  }

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
    const entry = this.entryTargets.find((e) => e.contains(event.target))
    const destroyField = this.destroyTargets.find((d) => entry.contains(d))

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

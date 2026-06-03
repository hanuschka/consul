import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio"]

  connect() {
    this.onRadioChange = this.onRadioChange.bind(this)

    this.radioTargets.forEach((radio) => {
      radio.addEventListener("change", this.onRadioChange)
    })

    this.restoreFromHash()
  }

  disconnect() {
    this.radioTargets.forEach((radio) => {
      radio.removeEventListener("change", this.onRadioChange)
    })
  }

  restoreFromHash() {
    const phaseId = this.phaseIdFromHash()

    if (!phaseId) return

    const radio = this.radioTargets.find((r) => r.dataset.phaseId === phaseId)

    if (!radio || radio.checked) return

    radio.checked = true
  }

  onRadioChange(event) {
    const phaseId = event.currentTarget.dataset.phaseId

    if (!phaseId) return

    history.replaceState(null, "", `#phase-${phaseId}`)
  }

  phaseIdFromHash() {
    const hash = window.location.hash

    if (!hash.startsWith("#phase-")) return null

    return hash.slice("#phase-".length)
  }
}

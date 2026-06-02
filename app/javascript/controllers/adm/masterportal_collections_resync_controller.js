import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "button"]

  static values = {
    chunkSize: { type: Number, default: 3 },
    pauseMs: { type: Number, default: 8000 },
    updateConfirm: String,
    cleanConfirm: String
  }

  resync(event) {
    return this.runBulk(event, (controller) => controller.resync())
  }

  updateAll(event) {
    if (this.updateConfirmValue && !window.confirm(this.updateConfirmValue)) return

    return this.runBulk(event, (controller) => controller.kickoffUpdate(), { reloadAfter: true })
  }

  cleanAll(event) {
    if (this.cleanConfirmValue && !window.confirm(this.cleanConfirmValue)) return

    return this.runBulk(event, (controller) => controller.cleanInPlace(), { reloadAfter: true })
  }

  async runBulk(event, action, options = {}) {
    if (this.running) return

    this.running = true
    this.activeButton = event ? event.currentTarget : null
    this.setRunning(true)

    const cards = this.cardTargets

    for (let index = 0; index < cards.length; index += this.chunkSizeValue) {
      const chunk = cards.slice(index, index + this.chunkSizeValue)

      for (const card of chunk) {
        const controller = this.controllerFor(card)
        if (controller) await action(controller)
      }

      const hasMore = index + this.chunkSizeValue < cards.length
      if (hasMore) await this.pause()
    }

    if (options.reloadAfter) {
      window.location.reload()

      return
    }

    this.setRunning(false)
    this.running = false
    this.activeButton = null
  }

  controllerFor(card) {
    return this.application.getControllerForElementAndIdentifier(
      card, "adm--masterportal-collection"
    )
  }

  pause() {
    return new Promise((resolve) => window.setTimeout(resolve, this.pauseMsValue))
  }

  setRunning(isRunning) {
    this.buttonTargets.forEach((button) => {
      button.disabled = isRunning
      button.classList.toggle("-loading", isRunning && button === this.activeButton)
    })
  }
}

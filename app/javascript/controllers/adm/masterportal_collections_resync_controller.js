import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card", "button"]

  static values = {
    chunkSize: { type: Number, default: 3 },
    pauseMs: { type: Number, default: 8000 }
  }

  async resync() {
    if (this.running) return

    this.running = true
    this.setRunning(true)

    const cards = this.cardTargets

    for (let index = 0; index < cards.length; index += this.chunkSizeValue) {
      const chunk = cards.slice(index, index + this.chunkSizeValue)

      for (const card of chunk) {
        const controller = this.controllerFor(card)
        if (controller) await controller.resync()
      }

      const hasMore = index + this.chunkSizeValue < cards.length
      if (hasMore) await this.pause()
    }

    this.setRunning(false)
    this.running = false
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
    if (!this.hasButtonTarget) return

    this.buttonTarget.disabled = isRunning
    this.buttonTarget.classList.toggle("-loading", isRunning)
  }
}

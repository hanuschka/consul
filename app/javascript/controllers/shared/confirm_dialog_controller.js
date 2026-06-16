import { Controller } from "@hotwired/stimulus"

// Generic confirm dialog over a native <dialog> (kern-dialog). A trigger inside
// this controller opens it via open(); the confirm button dispatches a
// "confirmed" event the consumer wires its action to. Cancel, close, ESC and
// backdrop all just dismiss it.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    this.hideTriggerTooltip(event)
    this.dialogTarget.showModal()
  }

  // The trigger may sit inside a <rich-tooltip>; hide it so the tooltip doesn't
  // linger over the open modal.
  hideTriggerTooltip(event) {
    if (!event || !event.currentTarget) return

    const tooltip = event.currentTarget.closest("rich-tooltip")
    if (tooltip && typeof tooltip.hide === "function") tooltip.hide()
  }

  close() {
    this.dialogTarget.close()
  }

  confirm() {
    this.dispatch("confirmed")
    this.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}

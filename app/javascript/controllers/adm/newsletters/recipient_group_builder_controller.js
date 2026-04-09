import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  select(event) {
    const step = event.target.closest("[data-step]")
    let next = step.nextElementSibling
    while (next) {
      const toRemove = next
      next = next.nextElementSibling
      toRemove.remove()
    }
    event.target.closest("form").requestSubmit()
  }
}

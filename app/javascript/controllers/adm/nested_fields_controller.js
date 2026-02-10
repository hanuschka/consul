import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  add(event) {
    event.preventDefault()

    const content = this.templateTarget.innerHTML
    const time = new Date().getTime()
    const newContent = content.replace(/NEW_RECORD/g, time)

    this.containerTarget.insertAdjacentHTML("beforeend", newContent)
  }

  remove(event) {
    event.preventDefault()

    const wrapper = event.currentTarget.closest("[data-nested-field]")
    if (!wrapper) return

    const destroyInput = wrapper.querySelector("input[name*='_destroy']")

    if (destroyInput) {
      destroyInput.value = "1"
      wrapper.classList.add("d-none")
    } else {
      wrapper.remove()
    }
  }
}

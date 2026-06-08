import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.addEventListener("click", this.handleClick)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClick)
  }

  handleClick = (event) => {
    const head = event.target.closest(".js-collapse-head")

    if (!head) return

    event.stopPropagation()

    const collapseRoot = head.closest(".custom-collapse")

    if (!collapseRoot) return

    const isExpanded = collapseRoot.classList.toggle("-opened")
    head.setAttribute("aria-expanded", String(isExpanded))
  }
}

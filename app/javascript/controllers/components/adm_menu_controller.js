import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "expandable" ]

  connect() {
    this.expandableTargets.forEach((element) => {
      element.addEventListener("click", this.toggleExpanded)
      element.addEventListener("keypress", (event) => {
        if (event.key === "Enter" || event.key === " ") {
          this.toggleExpanded(event)
        }
      })
    })
  }

  toggleExpanded(event) {
    event.currentTarget.classList.toggle("expanded")
    event.currentTarget.setAttribute("aria-expanded", event.currentTarget.classList.contains("expanded"))
  }
}

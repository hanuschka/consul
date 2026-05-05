import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fields"]

  connect() {
    this.toggle()
  }

  toggle() {
    const checked = this.element.querySelector("input[type=checkbox][name*='open_answer']").checked
    this.fieldsTargets.forEach(el => {
      el.style.display = checked ? "none" : ""
    })
  }
}

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("ModeSwitcherController connected")
  }

  toggle() {
    document.body.classList.toggle("kern-dark")
  }
}

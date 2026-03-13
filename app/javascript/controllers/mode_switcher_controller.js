import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "label"]

  connect() {
    const isDark = this.getCookie("kern_dark_mode") === "1"
    document.body.classList.toggle("kern-dark", isDark)
    this.updateIcon()
  }

  toggle() {
    document.body.classList.toggle("kern-dark")
    const isDark = document.body.classList.contains("kern-dark")
    document.cookie = `kern_dark_mode=${isDark ? "1" : "0"}; path=/; max-age=${365 * 24 * 60 * 60}`
    this.updateIcon()
  }

  updateIcon() {
    if (!this.hasIconTarget) return
    const isDark = document.body.classList.contains("kern-dark")
    this.iconTarget.textContent = isDark ? "light_mode" : "dark_mode"
    if (this.hasLabelTarget) {
      this.labelTarget.textContent = isDark ? "Light mode" : "Dark mode"
    }
  }

  getCookie(name) {
    const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`))
    return match ? match[1] : null
  }
}

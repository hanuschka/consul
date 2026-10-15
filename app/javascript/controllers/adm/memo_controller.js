import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["replyForm"]

  toggleReplyForm() {
    this.replyFormTarget.hidden = !this.replyFormTarget.hidden

    if (this.replyFormTarget.hidden) return

    this.replyFormTarget.querySelector("textarea").focus()
  }
}

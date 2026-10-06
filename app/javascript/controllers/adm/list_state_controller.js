import { Controller } from "@hotwired/stimulus"
import { readListState, writeListState } from "../../utils/adm_list_state"

export default class extends Controller {
  connect() {
    if (document.documentElement.hasAttribute("data-turbo-preview")) return

    this.pagePath = window.location.pathname
    this.submittedIntoFrame = false
    this.pendingRestore = null

    const saved = this.element.src || window.location.search !== "" ? null : this.savedState()

    if (saved) {
      this.restore(saved)
    } else {
      this.remember()
    }
  }

  submitStarted({ target }) {
    if (this.targetsFrame(target)) this.submittedIntoFrame = true
  }

  submitEnded({ target, detail }) {
    if (this.targetsFrame(target) && !detail.fetchResponse?.redirected) this.submittedIntoFrame = false
  }

  targetsFrame(form) {
    const frameId = form.dataset.turboFrame

    return frameId ? frameId === this.element.id : this.element.contains(form)
  }

  carryOver(event) {
    const newFrame = event.detail.newBody.querySelector(`turbo-frame#${CSS.escape(this.element.id)}`)
    if (!newFrame || newFrame.hasAttribute("src") || window.location.search !== "") return

    const saved = readListState(window.location.pathname, this.element.id)
    if (!saved || saved === window.location.pathname || saved !== this.shownState()) return

    newFrame.innerHTML = this.element.innerHTML
    newFrame.setAttribute("src", saved)
  }

  shownState() {
    if (!this.element.src) return null

    const url = new URL(this.element.src, window.location.origin)

    return url.pathname + url.search
  }

  beforeRender(event) {
    if (!this.submittedIntoFrame) return

    this.submittedIntoFrame = false

    const saved = this.frameUrl().search === "" ? this.savedState() : null
    if (!saved) return

    this.pendingRestore = saved
    event.detail.render = () => {}
  }

  remember() {
    if (this.pendingRestore) {
      this.restore(this.pendingRestore)
      this.pendingRestore = null
      return
    }

    const url = this.frameUrl()

    writeListState(this.pagePath, this.element.id, url.pathname + url.search)
    this.reveal()
  }

  restore(saved) {
    this.element.style.visibility = "hidden"
    this.element.src = saved
  }

  reveal() {
    this.element.style.visibility = ""
  }

  frameUrl() {
    return new URL(this.element.src || window.location.href, window.location.origin)
  }

  savedState() {
    const saved = readListState(this.pagePath, this.element.id)

    if (!saved || saved === this.pagePath) return null

    return saved
  }
}

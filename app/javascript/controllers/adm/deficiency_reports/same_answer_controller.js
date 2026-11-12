import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "publicField", "privateHint", "publicHint"]
  static values = {
    reporterEditorId: String,
    publicEditorId: String
  }

  toggle() {
    const same = this.checkboxTarget.checked

    this.publicFieldTarget.hidden = same
    this.privateHintTarget.hidden = same
    this.publicHintTarget.hidden = !same

    if (same) this.prefillReporterAnswer()
  }

  prefillReporterAnswer() {
    const reporterEditor = this.editor(this.reporterEditorIdValue)
    const publicEditor = this.editor(this.publicEditorIdValue)
    if (!reporterEditor || !publicEditor) return
    if (reporterEditor.getData().trim() !== "") return

    reporterEditor.setData(publicEditor.getData())
  }

  editor(id) {
    return window.App?.HTMLEditor?.instances?.[id]
  }
}

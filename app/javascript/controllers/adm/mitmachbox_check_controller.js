import { Controller } from "@hotwired/stimulus"
import { analyzeOption, analyzeQuestion, loadFonts } from "../../lib/mitmachbox/box_engine"

export default class extends Controller {
  static targets = ["prompt", "type", "label", "alert", "list"]

  static values = {
    fontsUrl: String,
    prompt: String,
    multiple: Boolean,
    options: Array,
    index: Number,
    messages: Object
  }

  connect() {
    loadFonts(this.fontsUrlValue).then(() => {
      if (!this.element.isConnected) return

      this.ready = true
      this.check()
    })
  }

  check() {
    if (!this.ready) return

    this.render(this.hasLabelTarget ? this.optionMessages() : this.questionMessages())
  }

  questionMessages() {
    const labels = this.optionsValue
    const result = analyzeQuestion({
      prompt: this.promptTarget.value,
      multiple: this.hasTypeTarget && this.typeTarget.value === "multiple_choice",
      options: labels.map((label) => ({ label }))
    })
    const messages = []
    if (result.overflow) messages.push(this.t("prompt_overflow"))
    else if (result.shrunk) messages.push(this.t("prompt_shrunk"))
    messages.push(...this.textMessages(result))
    result.options.forEach((option, i) => {
      if (!option.overflow) return

      messages.push(this.t("existing_option_overflow", {
        number: i + 1,
        label: this.quoted(labels[i]),
        lines: option.lines,
        room: option.room
      }))
    })
    return messages
  }

  optionMessages() {
    const result = analyzeOption({ prompt: this.promptValue, multiple: this.multipleValue },
                                 this.labelTarget.value,
                                 this.indexValue)
    const messages = []
    if (result.overflow) messages.push(this.t("option_overflow", { lines: result.lines, room: result.room }))
    messages.push(...this.textMessages(result))
    return messages
  }

  textMessages(result) {
    const messages = result.splitWords.map((word) => this.t("word_split", { word: this.quoted(word) }))
    if (result.missing.length) {
      messages.push(this.t("missing", { characters: result.missing.map((char) => this.quoted(char)).join(", ") }))
    }
    return messages
  }

  render(messages) {
    const key = messages.join("\n")
    if (key === this.renderedKey) return

    this.renderedKey = key
    this.listTarget.replaceChildren(...messages.map((text) => {
      const item = document.createElement("li")
      item.textContent = text
      return item
    }))
    this.alertTarget.hidden = messages.length === 0
  }

  quoted(text) {
    return this.t("quoted", { text })
  }

  t(key, values = {}) {
    return String(this.messagesValue[key] ?? key).replace(/%\{(\w+)\}/g, (match, name) => (name in values ? values[name] : match))
  }
}

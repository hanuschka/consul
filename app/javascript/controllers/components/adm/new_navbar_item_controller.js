import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "presets", "projekts", "external", "customFields" ]

  kindChanged(event) {
    const targets = {
      presets: this.presetsTarget,
      projekts: this.hasProjektsTarget ? this.projektsTarget : null,
      external: this.hasExternalTarget ? this.externalTarget : null
    }

    Object.values(targets).forEach(target => {
      if (target) target.style.display = "none"
    })

    if (targets[event.target.value]) {
      targets[event.target.value].style.display = "block"
    }

    this.selectionChanged()
  }

  selectionChanged() {
    if (!this.hasCustomFieldsTarget) return

    this.customFieldsTarget.style.display = this._hasSelection() ? "block" : "none"
  }

  _hasSelection() {
    const kind = this._currentKind()

    if (kind === "presets") {
      return !!this.element.querySelector('input[name*="[preset]"]:checked')
    }

    if (kind === "projekts") {
      return !!this.element.querySelector('input[name*="[projekt_id]"]:checked')
    }

    if (kind === "external") {
      const input = this.element.querySelector('input[name*="[external_url]"]')
      return !!(input && input.value.trim() !== "")
    }

    return false
  }

  _currentKind() {
    const checkedKind = this.element.querySelector('input[type="radio"][name*="[kind]"]:checked')
    if (checkedKind) return checkedKind.value

    const hiddenKind = this.element.querySelector('input[type="hidden"][name*="[kind]"]')
    if (hiddenKind) return hiddenKind.value

    return null
  }
}

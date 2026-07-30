import { Controller } from "@hotwired/stimulus"
import { addFlashMessage } from "../../utils/adm_flash"

const SEARCH_DEBOUNCE_MS = 400

export default class extends Controller {
  static values = {
    type: String
  }

  static targets = [
    "form",
    "resultsFrame",
    "viewModeCardsButton",
    "viewModeListButton",
    "editModal",
    "editForm",
    "editTitle",
    "editDescription",
    "editAlt",
    "editAltField"
  ]

  connect() {
    this.searchTimer = null
    this.editingAsset = null

    this.restoreViewMode()
  }

  disconnect() {
    if (this.searchTimer) {
      clearTimeout(this.searchTimer)
      this.searchTimer = null
    }
  }

  viewModeCardsClicked() {
    this.setViewMode("cards")
  }

  viewModeListClicked() {
    this.setViewMode("list")
  }

  setViewMode(mode) {
    const normalized = mode === "list" ? "list" : "cards"

    this.element.classList.toggle("-view-list", normalized === "list")
    this.element.classList.toggle("-view-cards", normalized === "cards")

    if (this.hasViewModeCardsButtonTarget) {
      this.viewModeCardsButtonTarget.classList.toggle("-active", normalized === "cards")
    }
    if (this.hasViewModeListButtonTarget) {
      this.viewModeListButtonTarget.classList.toggle("-active", normalized === "list")
    }

    try {
      localStorage.setItem(this.viewModeStorageKey(), normalized)
    } catch (_error) {
      // localStorage unavailable; ignore
    }
  }

  restoreViewMode() {
    if (!this.hasViewModeCardsButtonTarget && !this.hasViewModeListButtonTarget) return

    let stored = "cards"

    try {
      stored = localStorage.getItem(this.viewModeStorageKey()) || "cards"
    } catch (_error) {
      stored = "cards"
    }

    this.setViewMode(stored)
  }

  viewModeStorageKey() {
    return `files-${this.typeValue}-view-mode`
  }

  inputChanged() {
    if (this.searchTimer) clearTimeout(this.searchTimer)

    this.searchTimer = setTimeout(() => {
      this.searchTimer = null
      this.submitFilters()
    }, SEARCH_DEBOUNCE_MS)
  }

  filterChanged() {
    this.submitFilters()
  }

  resetClicked() {
    this.clearFormInputs()
    this.submitFilters()
  }

  submitFilters() {
    this.formTarget.requestSubmit()
  }

  stripBlankEntries(event) {
    const formData = event.formData

    Array.from(formData.entries()).forEach(([key, value]) => {
      if (value === "") formData.delete(key)
    })
  }

  reloadResults() {
    const frame = this.resultsFrameTarget

    if (frame.src) {
      frame.reload()
    } else {
      frame.src = window.location.href
    }
  }

  async deleteClicked(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const card = button.closest(".files-asset-card") || button.closest(".files-asset-row")

    if (!card) return

    const confirmMessage = button.dataset.confirmMessage || "Delete?"
    if (!window.confirm(confirmMessage)) return

    const url = button.dataset.deleteUrl
    if (!url) return

    const filename = card.dataset.filename || ""

    try {
      const response = await fetch(url, {
        method: "DELETE",
        headers: {
          "X-CSRF-TOKEN": this.csrfToken(),
          "Accept": "application/json"
        }
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      this.reloadResults()
      addFlashMessage(this.deleteSuccessMessage(filename), "success")
    } catch (error) {
      console.error("Files delete failed", error)
      addFlashMessage(this.deleteFailedMessage(filename), "danger")
    }
  }

  async copyUrlClicked(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const url = button.dataset.copyUrl

    if (!url) return

    try {
      await navigator.clipboard.writeText(url)
      addFlashMessage(button.dataset.successMessage || "Link copied", "success")
    } catch (error) {
      console.error("Files copy url failed", error)
      addFlashMessage(button.dataset.failedMessage || "Copy failed", "danger")
    }
  }

  deleteSuccessMessage(filename) {
    return this.applyTemplate("data-files-delete-success-template", filename) ||
      `Deleted ${filename}`
  }

  deleteFailedMessage(filename) {
    const templated = this.applyTemplate("data-files-delete-failed-template", filename)
    if (templated) return templated

    const fallback = document.querySelector("[data-files-delete-failed-message]")

    return fallback ? fallback.getAttribute("data-files-delete-failed-message") : "Delete failed"
  }

  applyTemplate(attribute, filename) {
    const el = document.querySelector(`[${attribute}]`)
    if (!el) return null

    return el.getAttribute(attribute).replace("__FILENAME__", filename)
  }

  editClicked(event) {
    event.preventDefault()
    event.stopPropagation()

    const card = event.target.closest(".files-asset-card") || event.target.closest(".files-asset-row")

    if (!card) return

    this.editingAsset = card
    this.editTitleTarget.value = card.dataset.title || ""
    this.editDescriptionTarget.value = card.dataset.description || ""
    this.editAltTarget.value = card.dataset.altText || ""

    const onlyTitle = card.dataset.onlyTitle === "true"
    const descriptionField = this.editDescriptionTarget.closest(".files-edit-modal--field")

    if (onlyTitle) {
      if (descriptionField) descriptionField.style.display = "none"
      this.editAltFieldTarget.style.display = "none"
    } else {
      if (descriptionField) descriptionField.style.display = ""
      this.editAltFieldTarget.style.display = card.dataset.type === "picture" ? "" : "none"
    }

    this.editModalTarget.showModal()
  }

  editModalClose(event) {
    if (event) event.preventDefault()

    this.editModalTarget.close()
    this.editingAsset = null
  }

  editModalBackdrop(event) {
    if (event.target === this.editModalTarget) this.editModalClose()
  }

  async editModalSubmit(event) {
    event.preventDefault()

    if (!this.editingAsset) return

    const card = this.editingAsset
    const formData = this.buildEditFormData(card)

    try {
      const data = await this.patchAsset(card, formData)

      this.applyUpdateToCard(card, data)
      this.editModalClose()
    } catch (error) {
      console.error("Files edit submit failed", error)
      alert(this.editFailedMessage())
    }
  }

  async altPopupSave(event) {
    event.preventDefault()

    const button = event.currentTarget
    const popup = button.closest("inline-popup")
    const card = button.closest(".files-asset-card") || button.closest(".files-asset-row")

    if (!card) return

    const altText = popup.querySelector(".js-files-alt-input").value.trim()

    const formData = new FormData()
    formData.append("picture[alt_text]", altText)

    button.disabled = true

    try {
      const data = await this.patchAsset(card, formData)

      this.applyUpdateToCard(card, data)
      popup.close()
    } catch (error) {
      console.error("Files alt save failed", error)
      addFlashMessage(this.editFailedMessage(), "danger")
    } finally {
      button.disabled = false
    }
  }

  assetUpdateUrl(card) {
    if (card.dataset.updateUrl) return card.dataset.updateUrl

    const fallbackEndpoint = card.dataset.type === "picture" ? "/ckeditor/pictures" : "/ckeditor/documents"

    return `${fallbackEndpoint}/${card.dataset.id}`
  }

  async patchAsset(card, formData) {
    const response = await fetch(this.assetUpdateUrl(card), {
      method: "PATCH",
      headers: {
        "X-CSRF-TOKEN": this.csrfToken(),
        "Accept": "application/json"
      },
      body: formData
    })

    if (!response.ok) throw new Error(`HTTP ${response.status}`)

    return response.json()
  }

  buildEditFormData(card) {
    const formData = new FormData()
    const onlyTitle = card.dataset.onlyTitle === "true"
    const type = card.dataset.type

    if (onlyTitle) {
      formData.append(`${type}[title]`, this.editTitleTarget.value)
      return formData
    }

    formData.append(`${type}[title]`, this.editTitleTarget.value)
    formData.append(`${type}[description]`, this.editDescriptionTarget.value)

    if (type === "picture") {
      formData.append(`${type}[alt_text]`, this.editAltTarget.value)
    }

    return formData
  }

  applyUpdateToCard(card, data) {
    if (data.title !== undefined) card.dataset.title = data.title || ""
    if (data.description !== undefined) card.dataset.description = data.description || ""
    if (data.alt_text !== undefined) card.dataset.altText = data.alt_text || ""

    this.syncAltTextDisplay(card)
  }

  syncAltTextDisplay(card) {
    const badge = card.querySelector(".js-files-alt-badge")

    if (!badge) return

    const altText = (card.dataset.altText || "").trim()
    const input = card.querySelector(".js-files-alt-input")

    badge.dataset.altState = altText ? "set" : "missing"
    card.querySelector(".js-files-alt-text-row").hidden = altText === ""
    card.querySelector(".js-files-alt-text-value").textContent = altText

    if (input) input.value = altText
  }

  csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')

    return meta ? meta.getAttribute("content") : ""
  }

  editFailedMessage() {
    const el = document.querySelector("[data-files-edit-failed-message]")

    return el ? el.getAttribute("data-files-edit-failed-message") : "Update failed"
  }

  clearFormInputs() {
    this.formTarget.querySelectorAll("input, select").forEach((input) => {
      if (input.tagName === "SELECT") {
        input.selectedIndex = 0
      } else {
        input.value = ""
      }
    })
  }
}

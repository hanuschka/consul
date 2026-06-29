import { Controller } from "@hotwired/stimulus"
import { addFlashMessage } from "../../utils/adm_flash"

const SEARCH_DEBOUNCE_MS = 400

export default class extends Controller {
  static values = {
    type: String,
    endpoint: String
  }

  static targets = [
    "form",
    "grid",
    "list",
    "pagination",
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
    this.currentPage = 1
    this.searchTimer = null
    this.editingAsset = null

    this.onPaginationClick = this.onPaginationClick.bind(this)
    this.onPopState = this.onPopState.bind(this)

    this.hydrateFromUrl()
    this.restoreViewMode()

    this.paginationTarget.addEventListener("click", this.onPaginationClick)
    window.addEventListener("popstate", this.onPopState)
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

  disconnect() {
    if (this.searchTimer) {
      clearTimeout(this.searchTimer)
      this.searchTimer = null
    }

    this.paginationTarget.removeEventListener("click", this.onPaginationClick)
    window.removeEventListener("popstate", this.onPopState)
  }

  inputChanged() {
    if (this.searchTimer) clearTimeout(this.searchTimer)

    this.searchTimer = setTimeout(() => {
      this.searchTimer = null
      this.currentPage = 1
      this.refresh()
    }, SEARCH_DEBOUNCE_MS)
  }

  filterChanged() {
    this.currentPage = 1
    this.refresh()
  }

  sortChanged() {
    this.currentPage = 1
    this.refresh()
  }

  resetClicked() {
    this.clearFormInputs()
    this.currentPage = 1
    this.refresh()
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

      card.remove()
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

  onPaginationClick(event) {
    const link = event.target.closest("a")

    if (!link) return
    if (!this.paginationTarget.contains(link)) return

    event.preventDefault()

    this.currentPage = this.extractPageFromHref(link.getAttribute("href"))
    this.refresh()
  }

  onPopState() {
    this.hydrateFromUrl()
    this.refresh({ pushState: false })
  }

  async refresh({ pushState = true } = {}) {
    const url = this.buildUrl()

    if (pushState) history.pushState(null, "", url)

    const response = await fetch(url, {
      headers: {
        "Accept": "text/html",
        "X-Requested-With": "XMLHttpRequest"
      }
    })
    const html = await response.text()

    this.replaceContent(html)
  }

  hydrateFromUrl() {
    const serializer = window.FilesFilterSerializer
    const params = serializer.parseUrlParams(window.location.search)

    serializer.applyToForm(this.formTarget, params)

    const pageParam = params.page
    const parsedPage = parseInt(pageParam || "1", 10)

    this.currentPage = isNaN(parsedPage) || parsedPage < 1 ? 1 : parsedPage
  }

  buildUrl() {
    const serializer = window.FilesFilterSerializer
    const params = serializer.serializeForm(this.formTarget)

    params.type = this.typeValue

    if (this.currentPage > 1) {
      params.page = String(this.currentPage)
    }

    return serializer.urlForParams(this.endpointValue, params)
  }

  replaceContent(html) {
    const doc = new DOMParser().parseFromString(html, "text/html")
    const newGrid = doc.querySelector(".files-index--grid")
    const newListItems = doc.querySelector(".files-index--list-items")
    const newPagination = doc.querySelector(".files-index--pagination")

    if (newGrid) this.gridTarget.innerHTML = newGrid.innerHTML
    if (newListItems && this.hasListTarget) this.listTarget.innerHTML = newListItems.innerHTML
    if (newPagination) this.paginationTarget.innerHTML = newPagination.innerHTML
  }

  clearFormInputs() {
    const selectors = [
      ".js-fm-filter-search",
      ".js-fm-filter-extension",
      ".js-fm-filter-size-min",
      ".js-fm-filter-size-max",
      ".js-fm-filter-created-from",
      ".js-fm-filter-created-to",
      ".js-fm-filter-updated-from",
      ".js-fm-filter-updated-to",
      ".js-fm-filter-imageable-type",
      ".js-fm-filter-documentable-type",
      ".js-fm-filter-sort"
    ]

    selectors.forEach((selector) => {
      const input = this.formTarget.querySelector(selector)

      if (!input) return

      if (input.tagName === "SELECT") {
        input.selectedIndex = 0
      } else {
        input.value = ""
      }
    })
  }

  extractPageFromHref(href) {
    if (!href) return 1

    try {
      const parsed = new URL(href, window.location.origin)
      const pageParam = parsed.searchParams.get("page")
      const parsedPage = parseInt(pageParam || "1", 10)

      return isNaN(parsedPage) || parsedPage < 1 ? 1 : parsedPage
    } catch (_error) {
      return 1
    }
  }
}

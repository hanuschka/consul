import { Controller } from "@hotwired/stimulus"

const SEARCH_DEBOUNCE_MS = 200

export default class extends Controller {
  static values = {
    type: String,
    endpoint: String
  }

  static targets = [
    "form",
    "grid",
    "pagination",
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

    this.paginationTarget.addEventListener("click", this.onPaginationClick)
    window.addEventListener("popstate", this.onPopState)
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
    const card = button.closest(".files-asset-card")

    if (!card) return

    const confirmMessage = button.dataset.confirmMessage || "Delete?"
    if (!window.confirm(confirmMessage)) return

    const url = button.dataset.deleteUrl
    if (!url) return

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
    } catch (error) {
      console.error("Files delete failed", error)
      alert(this.deleteFailedMessage())
    }
  }

  deleteFailedMessage() {
    const el = document.querySelector("[data-files-delete-failed-message]")

    return el ? el.getAttribute("data-files-delete-failed-message") : "Delete failed"
  }

  editClicked(event) {
    event.preventDefault()
    event.stopPropagation()

    const card = event.target.closest(".files-asset-card")

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

  async editModalSubmit(event) {
    event.preventDefault()

    if (!this.editingAsset) return

    const card = this.editingAsset
    const updateUrl = card.dataset.updateUrl
    const id = card.dataset.id
    const type = card.dataset.type
    const fallbackEndpoint = type === "picture" ? "/ckeditor/pictures" : "/ckeditor/documents"
    const url = updateUrl || `${fallbackEndpoint}/${id}`

    const formData = this.buildEditFormData(card)

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-TOKEN": this.csrfToken(),
          "Accept": "application/json"
        },
        body: formData
      })

      if (!response.ok) throw new Error(`HTTP ${response.status}`)

      const data = await response.json()

      this.applyUpdateToCard(card, data)
      this.editModalClose()
    } catch (error) {
      console.error("Files edit submit failed", error)
      alert(this.editFailedMessage())
    }
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
    const newPagination = doc.querySelector(".files-index--pagination")

    if (newGrid) this.gridTarget.innerHTML = newGrid.innerHTML
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
      ".js-fm-filter-admin-flag",
      ".js-fm-filter-sort"
    ]

    selectors.forEach((selector) => {
      const input = this.formTarget.querySelector(selector)

      if (!input) return

      input.value = ""
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

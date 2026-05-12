import { Controller } from "@hotwired/stimulus"

const SEARCH_DEBOUNCE_MS = 200

export default class extends Controller {
  static values = {
    type: String,
    endpoint: String
  }

  static targets = ["form", "grid", "pagination"]

  connect() {
    this.currentPage = 1
    this.searchTimer = null

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

  searchChanged() {
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

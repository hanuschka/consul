import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "startInput", "endInput", "resetLink", "wrapper"]

  disconnect() {
    this.abortController?.abort()
  }

  rangeChanged() {
    this.fetchRange({ start_date: this.startInputTarget.value, end_date: this.endInputTarget.value })
  }

  reset(event) {
    event.preventDefault()
    this.startInputTarget.value = ""
    this.startInputTarget.setAttribute("value", "")
    this.endInputTarget.value = ""
    this.endInputTarget.setAttribute("value", "")
    this.fetchRange({})
  }

  async fetchRange(params) {
    this.abortController?.abort()
    this.abortController = new AbortController()

    let payload
    try {
      const response = await fetch(this.jsonUrl(params), {
        headers: { Accept: "application/json" },
        credentials: "same-origin",
        signal: this.abortController.signal
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      payload = await response.json()
    } catch (error) {
      if (error.name === "AbortError") return
      this.formTarget.requestSubmit()
      return
    }

    this.applyPayload(payload)
  }

  applyPayload(payload) {
    const range = payload.range || {}

    this.wrapperTarget.dataset.chartDatasets = JSON.stringify(payload.datasets)
    this.startInputTarget.value = range.start_date || ""
    this.startInputTarget.setAttribute("value", range.start_date || "")
    this.endInputTarget.value = range.end_date || ""
    this.endInputTarget.setAttribute("value", range.end_date || "")
    this.resetLinkTarget.hidden = !(range.start_date || range.end_date)

    this.wrapperTarget.dispatchEvent(new CustomEvent("adm-charts:datasets-changed", { bubbles: true }))

    const path = this.formTarget.getAttribute("action")
    const query = this.buildQuery(range)
    window.history.replaceState(window.history.state, "", query ? `${path}?${query}` : path)
  }

  jsonUrl(params) {
    const action = this.formTarget.action.split("?")[0]
    const query = this.buildQuery(params)
    return `${action}.json${query ? `?${query}` : ""}`
  }

  buildQuery(params) {
    const query = new URLSearchParams()
    if (params.start_date) query.set("start_date", params.start_date)
    if (params.end_date) query.set("end_date", params.end_date)
    return query.toString()
  }
}

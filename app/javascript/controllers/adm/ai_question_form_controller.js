import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "input", "submit", "pendingSection", "downloadAll", "loading"]

  static values = {
    pendingListSelector: String,
    historyListSelector: String
  }

  connect() {
    this.onPendingListChange = this.onPendingListChange.bind(this)
    this.onHistoryListChange = this.onHistoryListChange.bind(this)
    this.onSubmitStart = this.onSubmitStart.bind(this)
    this.onSubmitEnd = this.onSubmitEnd.bind(this)

    this.pendingList = document.querySelector(this.pendingListSelectorValue)
    this.historyList = document.querySelector(this.historyListSelectorValue)

    this.observePendingList()
    this.observeHistoryList()

    this.formTarget.addEventListener("turbo:submit-start", this.onSubmitStart)
    this.formTarget.addEventListener("turbo:submit-end", this.onSubmitEnd)

    this.refreshState()
  }

  disconnect() {
    if (this.pendingObserver) this.pendingObserver.disconnect()
    if (this.historyObserver) this.historyObserver.disconnect()

    this.formTarget.removeEventListener("turbo:submit-start", this.onSubmitStart)
    this.formTarget.removeEventListener("turbo:submit-end", this.onSubmitEnd)
  }

  observePendingList() {
    if (!this.pendingList) return

    this.pendingObserver = new MutationObserver(this.onPendingListChange)
    this.pendingObserver.observe(this.pendingList, { childList: true })
  }

  observeHistoryList() {
    if (!this.historyList) return

    this.historyObserver = new MutationObserver(this.onHistoryListChange)
    this.historyObserver.observe(this.historyList, { childList: true })
  }

  onPendingListChange() {
    this.refreshState()
  }

  onHistoryListChange() {
    this.refreshDownloadAll()
  }

  onSubmitStart() {
    this.submitting = true
    this.refreshState()
  }

  onSubmitEnd(event) {
    this.submitting = false

    if (event.detail.success) this.inputTarget.value = ""

    this.refreshState()
  }

  refreshState() {
    const hasPending = this.pendingCount() > 0
    const disabled = hasPending || this.submitting

    this.inputTarget.disabled = disabled
    this.submitTarget.disabled = disabled

    if (this.hasPendingSectionTarget) {
      this.pendingSectionTarget.classList.toggle("hidden", !hasPending)
    }

    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.toggle("hidden", !this.submitting)
    }

    this.refreshDownloadAll()
  }

  refreshDownloadAll() {
    if (!this.hasDownloadAllTarget) return

    this.downloadAllTarget.classList.toggle("hidden", this.historyCount() === 0)
  }

  pendingCount() {
    if (!this.pendingList) return 0

    return this.pendingList.children.length
  }

  historyCount() {
    if (!this.historyList) return 0

    return this.historyList.children.length
  }
}

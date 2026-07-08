import { Controller } from "@hotwired/stimulus"
import AjaxFetch from "../../shared/ajax_fetch"

const INITIAL_PROGRESS_DELAY = 1200
const INITIAL_PROGRESS_PERCENT = 20

// Polls a projekt-import's status endpoint and advances the analysis progress UI,
// redirecting to the chat once analysis is ready. Drives the dedicated loading
// screen used both right after upload and when resuming an in-flight import, so a
// page reload never loses analysis progress. On failure it reloads to let the
// server render the failed/stalled detail screen.
export default class extends Controller {
  static targets = ["progressLabel", "progressFill"]

  static values = {
    statusUrl: String,
    chatUrl: String,
    pollInterval: { type: Number, default: 2000 },
    progressExtracting: String,
    progressProcessing: String,
    progressChatting: String
  }

  connect() {
    this.pollTimer = null
    this.initialTimer = null

    this.startInitialProgress()
  }

  disconnect() {
    this.clearPollTimer()
    this.clearInitialTimer()
  }

  startInitialProgress() {
    this.setProgress(0)

    this.initialTimer = setTimeout(() => {
      this.setProgress(INITIAL_PROGRESS_PERCENT)

      if (this.hasStatusUrlValue) this.pollStatus()
    }, INITIAL_PROGRESS_DELAY)
  }

  clearInitialTimer() {
    if (this.initialTimer) {
      clearTimeout(this.initialTimer)
      this.initialTimer = null
    }
  }

  pollStatus() {
    this.clearPollTimer()

    AjaxFetch.get(this.statusUrlValue)
      .then((data) => this.handleStatus(data))
      .catch(() => this.schedulePoll())
  }

  schedulePoll() {
    this.pollTimer = setTimeout(() => this.pollStatus(), this.pollIntervalValue)
  }

  clearPollTimer() {
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)
      this.pollTimer = null
    }
  }

  handleStatus(data) {
    switch (data.status) {
      case "extracting":
        this.advance(this.progressExtractingValue, 35)
        this.schedulePoll()
        break
      case "processing":
        this.advance(this.progressProcessingValue, 70)
        this.schedulePoll()
        break
      case "chatting":
        this.advance(this.progressChattingValue, 100)
        window.location.href = data.chat_url || this.chatUrlValue
        break
      case "failed":
        this.clearPollTimer()
        window.location.reload()
        break
      default:
        this.schedulePoll()
    }
  }

  advance(label, percent) {
    if (this.hasProgressLabelTarget) this.progressLabelTarget.textContent = label

    this.setProgress(percent)
  }

  setProgress(percent) {
    if (this.hasProgressFillTarget) {
      this.progressFillTarget.style.width = `${Math.max(0, Math.min(100, percent))}%`
    }
  }
}

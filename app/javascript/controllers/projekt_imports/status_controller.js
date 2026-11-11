import { Controller } from "@hotwired/stimulus"
import AjaxFetch from "../../shared/ajax_fetch"
import SUBMIT_STAGE_PERCENTS from "./submit_stage_percents"

const INITIAL_PROGRESS_DELAY = 1200
const INITIAL_PROGRESS_PERCENT = 20

// Polls a projekt-import's status endpoint and advances the analysis progress UI,
// redirecting to the chat once analysis is ready. Drives the dedicated loading
// screen used both right after upload and when resuming an in-flight import, so a
// page reload never loses analysis progress. A copied Consul projekt has no chat
// to show its final import over, so this screen follows that import too and
// reloads once it is done, letting the server send the admin on to the projekt.
// On failure it reloads to let the server render the failed/stalled detail screen.
export default class extends Controller {
  static targets = ["progressLabel", "progressFill"]

  static values = {
    statusUrl: String,
    reviewUrl: String,
    pollInterval: { type: Number, default: 2000 },
    progressExtracting: String,
    progressProcessing: String,
    progressChatting: String,
    submitProgressLabels: { type: Object, default: {} }
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
        window.location.href = data.review_url || this.reviewUrlValue
        break
      case "submitting":
        this.advanceSubmitStage(data.submit_stage)
        this.schedulePoll()
        break
      case "completed":
        this.clearPollTimer()
        this.setProgress(100)
        window.location.reload()
        break
      case "failed":
        this.clearPollTimer()
        window.location.reload()
        break
      default:
        this.schedulePoll()
    }
  }

  // A stage that is not known here (a poll that raced ahead of a deploy) keeps
  // whatever the bar last showed rather than blanking it.
  advanceSubmitStage(stage) {
    const stageKey = stage || "queued"
    const percent = SUBMIT_STAGE_PERCENTS[stageKey]

    if (percent === undefined) return

    this.advance(this.submitProgressLabelsValue[stageKey] || "", percent)
  }

  // The bar only moves forward: the opening step already sits past the
  // final import's "queued" position.
  advance(label, percent) {
    if (this.hasProgressLabelTarget) this.progressLabelTarget.textContent = label

    this.setProgress(Math.max(percent, this.progressPercent))
  }

  setProgress(percent) {
    this.progressPercent = percent

    if (this.hasProgressFillTarget) {
      this.progressFillTarget.style.width = `${Math.max(0, Math.min(100, percent))}%`
    }
  }
}

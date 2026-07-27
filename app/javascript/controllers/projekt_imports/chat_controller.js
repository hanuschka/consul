import { Controller } from "@hotwired/stimulus"

// Stop polling after this many consecutive failed /messages requests so a
// persistently-down endpoint isn't hammered every 2s forever.
const MAX_POLL_ERRORS = 5

// Treat the user as "following" the conversation when the messages container
// is scrolled within this many px of the bottom. Re-rendered messages only
// auto-scroll when the user is already near the bottom.
const SCROLL_BOTTOM_THRESHOLD = 80

// Final-import overlay bar. The import status endpoint only reports
// completed/failed, so the bar creeps through these staged percents on a timer
// to signal work is happening, then snaps to 100% on completion. Priming from
// 0% happens after OVERLAY_PROGRESS_INITIAL_DELAY; later steps advance every
// OVERLAY_PROGRESS_STEP_DELAY, holding at the last step until the import ends.
const OVERLAY_PROGRESS_INITIAL_DELAY = 1200
const OVERLAY_PROGRESS_STEP_DELAY = 2500
const OVERLAY_PROGRESS_STEPS = [
  { percent: 20, labelValue: "progressFinalizing" },
  { percent: 40, labelValue: "progressResolving" },
  { percent: 60, labelValue: "progressCreating" },
  { percent: 85, labelValue: "progressGeneratingImage" }
]

// Chat screen: polls /messages for new messages (after=:last_id) plus refreshed
// state for messages still in progress (pending[]=:ids), so finished messages
// are never re-rendered. Supports mid-chat document attach, four command
// buttons, and the final import overlay.
export default class extends Controller {
  static targets = [
    "messages", "form", "textarea", "sendButton",
    "attachments", "typingIndicator", "overlay", "overlayLabel", "overlayFill",
    "importError", "importErrorMessage", "generateImage", "importButton"
  ]

  static values = {
    messagesUrl: String,
    sendUrl: String,
    commandUrl: String,
    extractUrl: String,
    statusUrl: String,
    importId: Number,
    csrf: String,
    pollInterval: { type: Number, default: 2000 },
    confirmStartOver: String,
    progressFinalizing: String,
    progressResolving: String,
    progressCreating: String,
    progressGeneratingImage: String,
    errorExtractFailed: String,
    userInitials: { type: String, default: "" },
    userImageUrl: { type: String, default: "" },
    importStatus: { type: String, default: "" }
  }

  connect() {
    this.lastMessageId = this.computeLastMessageId()
    this.attachedDocuments = []
    this.pollTimer = null
    this.statusPollTimer = null
    this.lastImportStatus = null
    this.completionShown = this.importStatusValue === "completed"
    this.pollErrorCount = 0
    this.chatRunning = false
    this.initialTextareaOffset = this.textareaTarget.offsetHeight - this.textareaTarget.clientHeight
    this.refreshBusyState()
    this.scheduleMessagesPoll()

    if (this.importStatusValue === "submitting") {
      this.showOverlay()
      this.scheduleStatusPoll()
    }
  }

  disconnect() {
    this.clearPollTimer()
    this.clearStatusPollTimer()
    this.clearOverlayStepTimer()
  }

  computeLastMessageId() {
    const nodes = this.messagesTarget.querySelectorAll("[data-message-id]")
    let max = 0
    nodes.forEach((node) => {
      const id = Number(node.dataset.messageId)
      if (id > max) max = id
    })
    return max
  }

  scheduleMessagesPoll() {
    this.clearPollTimer()
    this.pollTimer = setTimeout(() => this.pollMessages(), this.pollIntervalValue)
  }

  clearPollTimer() {
    if (this.pollTimer) {
      clearTimeout(this.pollTimer)
      this.pollTimer = null
    }
  }

  pollMessages() {
    fetch(this.buildMessagesUrl(), {
      credentials: "same-origin",
      headers: { "Accept": "application/json" }
    })
      .then((response) => {
        if (!response.ok) throw new Error(`HTTP ${response.status}`)

        return response.json()
      })
      .then((data) => {
        this.pollErrorCount = 0
        this.handleMessages(data)
      })
      .catch(() => this.handlePollError())
  }

  buildMessagesUrl() {
    const params = new URLSearchParams()
    params.set("after", this.lastMessageId)
    this.pendingMessageIds().forEach((id) => params.append("pending[]", id))

    return `${this.messagesUrlValue}?${params.toString()}`
  }

  pendingMessageIds() {
    const selector =
      "[data-message-id][data-status='scheduled'], [data-message-id][data-status='running']"
    const nodes = this.messagesTarget.querySelectorAll(selector)

    return Array.from(nodes).map((node) => Number(node.dataset.messageId))
  }

  handlePollError() {
    this.pollErrorCount += 1
    if (this.pollErrorCount >= MAX_POLL_ERRORS) return

    this.scheduleMessagesPoll()
  }

  handleMessages(data) {
    if (Array.isArray(data.messages)) {
      data.messages.forEach((m) => this.appendOrUpdateMessage(m))
    }

    this.toggleTypingIndicator(Boolean(data.ai_chat && data.ai_chat.running))

    if (data.import) {
      this.handleImportState(data.import)
    } else {
      this.scheduleMessagesPoll()
    }
  }

  appendOrUpdateMessage(m) {
    if (!m.html) return

    if (m.role === "user") this.removeOptimisticBubbles()

    const existing = this.messagesTarget.querySelector(`[data-message-id="${m.id}"]`)
    const wasNearBottom = this.isNearBottom()
    const template = document.createElement("template")
    template.innerHTML = m.html.trim()
    const fresh = template.content.firstElementChild
    if (!fresh) return

    if (existing) {
      existing.replaceWith(fresh)
    } else {
      this.messagesTarget.insertBefore(fresh, this.typingIndicatorTarget)
    }

    if (m.id > this.lastMessageId) this.lastMessageId = m.id

    if (!existing || wasNearBottom) this.scrollToBottom()
  }

  // A pending assistant placeholder bubble already shows its own loader, so the
  // standalone typing indicator would be a duplicate — only show it when the
  // chat is running and no in-progress bubble is present.
  toggleTypingIndicator(running) {
    const redundant = this.pendingMessageIds().length > 0
    this.typingIndicatorTarget.classList.toggle("-hidden", !running || redundant)
    this.chatRunning = running
    this.refreshBusyState()
  }

  // The final import must not start while the assistant is still producing a
  // message, so the primary button is gated whenever a reply is in flight:
  // an optimistic user bubble is awaiting its response, a placeholder assistant
  // bubble is scheduled/running, or the chat reports it is running.
  isChatBusy() {
    const hasOptimistic =
      Boolean(this.messagesTarget.querySelector(".is-optimistic:not(.-failed)"))

    return hasOptimistic || this.pendingMessageIds().length > 0 || this.chatRunning
  }

  // Reflects the in-flight reply on both actions. The import button uses
  // aria-disabled + a state class (not the native attribute) so it stays
  // hoverable and its rich tooltip can explain the wait; the send button is a
  // plain submit, so native disabled (dimmed via its :disabled style) is fine.
  refreshBusyState() {
    const busy = this.isChatBusy()
    this.element.classList.toggle("-import-busy", busy)

    if (this.hasImportButtonTarget) {
      this.importButtonTarget.setAttribute("aria-disabled", busy ? "true" : "false")
    }

    if (this.hasSendButtonTarget) {
      this.sendButtonTarget.disabled = busy
    }
  }

  guardImport(event) {
    if (!this.isChatBusy()) return

    event.preventDefault()
    event.stopImmediatePropagation()
  }

  isNearBottom() {
    const el = this.messagesTarget
    return el.scrollHeight - el.scrollTop - el.clientHeight < SCROLL_BOTTOM_THRESHOLD
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  handleImportState(state) {
    if (state.status === "submitting") {
      this.showOverlay()
      this.scheduleStatusPoll()
      return
    }

    if (state.status === "completed") {
      this.handleCompletion(state.redirect_path)
      return
    }

    if (state.status === "failed" && this.lastImportStatus !== "failed") {
      this.hideOverlay()
      this.showImportError(state.error)
    }

    this.lastImportStatus = state.status
    this.scheduleMessagesPoll()
  }

  // When the import finishes live in this session (overlay showing), send the
  // user to the created projekt's frontend page. Revisiting an already-completed
  // import (guard) keeps the chat with its success state instead of redirecting.
  handleCompletion(redirectPath) {
    if (this.completionShown) {
      this.hideOverlay()
      this.scheduleMessagesPoll()
      return
    }

    this.completionShown = true
    this.completeOverlayProgress()

    if (redirectPath) {
      window.location.href = redirectPath
      return
    }

    this.hideOverlay()
    window.location.reload()
  }

  showImportError(message) {
    this.importErrorMessageTarget.textContent =
      message || this.importErrorTarget.dataset.fallback || ""
    this.importErrorTarget.classList.remove("-hidden")
  }

  dismissImportError() {
    this.importErrorTarget.classList.add("-hidden")
  }

  scheduleStatusPoll() {
    this.clearStatusPollTimer()
    this.statusPollTimer = setTimeout(() => this.pollStatus(), this.pollIntervalValue)
  }

  clearStatusPollTimer() {
    if (this.statusPollTimer) {
      clearTimeout(this.statusPollTimer)
      this.statusPollTimer = null
    }
  }

  pollStatus() {
    fetch(this.statusUrlValue, {
      credentials: "same-origin",
      headers: { "Accept": "application/json" }
    })
      .then((response) => response.json())
      .then((data) => {
        if (data.status === "completed") {
          this.handleCompletion(data.redirect_path)
          return
        }
        if (data.status === "failed") {
          this.hideOverlay()
          this.showImportError(data.error)
          return
        }
        this.scheduleStatusPoll()
      })
      .catch(() => this.scheduleStatusPoll())
  }

  showOverlay() {
    this.overlayTarget.classList.remove("-hidden")
    this.startOverlayProgress()
  }

  hideOverlay() {
    this.overlayTarget.classList.add("-hidden")
    this.clearOverlayStepTimer()
    this.overlayProgressStarted = false
  }

  startOverlayProgress() {
    if (this.overlayProgressStarted) return

    this.overlayProgressStarted = true
    this.overlayStepIndex = 0
    this.setOverlayProgress(0)
    this.setOverlayLabel(OVERLAY_PROGRESS_STEPS[0].labelValue)
    this.scheduleOverlayStep(OVERLAY_PROGRESS_INITIAL_DELAY)
  }

  scheduleOverlayStep(delay) {
    this.clearOverlayStepTimer()
    this.overlayStepTimer = setTimeout(() => this.advanceOverlayStep(), delay)
  }

  clearOverlayStepTimer() {
    if (this.overlayStepTimer) {
      clearTimeout(this.overlayStepTimer)
      this.overlayStepTimer = null
    }
  }

  advanceOverlayStep() {
    const step = OVERLAY_PROGRESS_STEPS[this.overlayStepIndex]
    if (!step) return

    this.setOverlayProgress(step.percent)
    this.setOverlayLabel(step.labelValue)
    this.overlayStepIndex += 1

    if (this.overlayStepIndex < OVERLAY_PROGRESS_STEPS.length) {
      this.scheduleOverlayStep(OVERLAY_PROGRESS_STEP_DELAY)
    }
  }

  completeOverlayProgress() {
    this.clearOverlayStepTimer()
    this.setOverlayProgress(100)
  }

  setOverlayProgress(percent) {
    if (this.hasOverlayFillTarget) {
      this.overlayFillTarget.style.width = `${Math.max(0, Math.min(100, percent))}%`
    }
  }

  setOverlayLabel(labelValue) {
    this.overlayLabelTarget.textContent = this[`${labelValue}Value`]
  }

  submit(event) {
    event.preventDefault()
    const content = this.textareaTarget.value.trim()
    if (!content && this.attachedDocuments.length === 0) return

    this.sendButtonTarget.disabled = true

    const optimisticAttachments = this.attachedDocuments.slice()

    this.appendOptimisticUserBubble(content, optimisticAttachments)
    this.refreshBusyState()
    this.textareaTarget.value = ""
    this.textareaTarget.style.height = "auto"
    this.textareaTarget.classList.remove("-scrollable")
    this.attachedDocuments = []
    this.renderAttachments()

    const formData = new FormData()
    formData.append("content", content)
    if (optimisticAttachments.length > 0) {
      formData.append("attached_documents", JSON.stringify(optimisticAttachments))
    }

    fetch(this.sendUrlValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfValue
      },
      body: formData
    })
      .then((response) => response.json())
      .then((data) => {
        this.removeOptimisticBubbles()
        this.renderImmediateMessages(data)
        this.scheduleMessagesPoll()
      })
      .catch(() => {
        this.markOptimisticAsFailed()
        this.refreshBusyState()
      })
  }

  renderImmediateMessages(data) {
    if (!data || !Array.isArray(data.messages)) return

    data.messages.forEach((m) => this.appendOrUpdateMessage(m))
    this.refreshBusyState()
  }

  appendOptimisticUserBubble(content, attachments) {
    const bubble = this.buildOptimisticUserBubble(content, attachments)
    this.messagesTarget.insertBefore(bubble, this.typingIndicatorTarget)
    this.scrollToBottom()
  }

  buildOptimisticUserBubble(content, attachments) {
    const bubble = document.createElement("div")
    bubble.className = "projekt-import-chat-bubble -user is-optimistic"
    bubble.setAttribute("data-status", "completed")

    bubble.appendChild(this.buildOptimisticAvatar())
    bubble.appendChild(this.buildOptimisticContentWrapper(content, attachments))

    return bubble
  }

  buildOptimisticAvatar() {
    const wrapper = document.createElement("div")
    wrapper.className = "projekt-import-chat-bubble--avatar-wrapper"

    const avatar = document.createElement("div")
    avatar.className = "projekt-import-chat-bubble--avatar -user"
    avatar.setAttribute("aria-hidden", "true")

    if (this.userImageUrlValue) {
      const img = document.createElement("img")
      img.src = this.userImageUrlValue
      img.alt = ""
      img.className = "projekt-import-chat-bubble--avatar-image"
      avatar.appendChild(img)
    } else if (this.userInitialsValue) {
      const span = document.createElement("span")
      span.className = "projekt-import-chat-bubble--avatar-initials"
      span.textContent = this.userInitialsValue
      avatar.appendChild(span)
    } else {
      const icon = document.createElement("span")
      icon.className = "material-symbols-outlined"
      icon.textContent = "person"
      avatar.appendChild(icon)
    }

    wrapper.appendChild(avatar)
    return wrapper
  }

  buildOptimisticContentWrapper(content, attachments) {
    const wrapper = document.createElement("div")
    wrapper.className = "projekt-import-chat-bubble--wrapper"

    const contentEl = document.createElement("div")
    contentEl.className = "projekt-import-chat-bubble--content"
    if (content) {
      const p = document.createElement("p")
      p.textContent = content
      contentEl.appendChild(p)
    }
    wrapper.appendChild(contentEl)

    if (attachments && attachments.length > 0) {
      wrapper.appendChild(this.buildOptimisticDocuments(attachments))
    }

    return wrapper
  }

  buildOptimisticDocuments(attachments) {
    const list = document.createElement("div")
    list.className = "projekt-import-chat--message-documents"

    attachments.forEach((doc) => {
      const badge = document.createElement("span")
      badge.className = "projekt-import-chat--document-badge"
      const icon = document.createElement("span")
      icon.className = "material-symbols-outlined"
      icon.setAttribute("aria-hidden", "true")
      icon.textContent = "description"
      badge.appendChild(icon)
      badge.appendChild(document.createTextNode(doc.name || ""))
      list.appendChild(badge)
    })

    return list
  }

  removeOptimisticBubbles() {
    const nodes = this.messagesTarget.querySelectorAll(".is-optimistic")
    nodes.forEach((node) => node.remove())
  }

  markOptimisticAsFailed() {
    const nodes = this.messagesTarget.querySelectorAll(".is-optimistic")
    nodes.forEach((node) => node.classList.add("-failed"))
  }

  textareaKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }

  textareaInput(event) {
    this.resizeTextarea(event.target)
  }

  resizeTextarea(textarea) {
    // Two-step: collapse to read true scrollHeight, then grow to fit content.
    textarea.style.height = "auto"
    const target = textarea.scrollHeight + this.initialTextareaOffset
    const max = parseFloat(getComputedStyle(textarea).maxHeight) || Infinity
    textarea.classList.toggle("-scrollable", target > max)
    textarea.style.height = target + "px"
  }

  regenerate() {
    this.sendCommand("regenerate").then((data) => this.renderImmediateMessages(data))
  }

  summarize() {
    this.sendCommand("summarize").then((data) => this.renderImmediateMessages(data))
  }

  // Invoked by the shared confirm dialog's "confirmed" event (not directly by
  // the import button), so the modal replaces the old window.confirm.
  startImport() {
    this.dismissImportError()
    this.lastImportStatus = null
    // A fresh import procedure starts now (incl. re-import of a completed one),
    // so its completion should redirect to the projekt even on a revisit.
    this.completionShown = false
    this.showOverlay()

    const params = { generate_image: this.generateImageTarget.checked ? "true" : "false" }

    this.sendCommand("import", params).then((data) => {
      if (data && data.status === "importing") {
        this.scheduleStatusPoll()
      }
    })
  }

  startOver() {
    if (!window.confirm(this.confirmStartOverValue)) return
    this.sendCommand("start_over").then((data) => {
      if (data && data.redirect_path) {
        window.location.href = data.redirect_path
      }
    })
  }

  sendCommand(name, params = {}) {
    const formData = new FormData()
    formData.append("name", name)
    Object.keys(params).forEach((key) => formData.append(key, params[key]))

    return fetch(this.commandUrlValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfValue
      },
      body: formData
    })
      .then((response) => response.json())
  }

  filesPicked(event) {
    const picked = Array.from(event.target.files || [])
    if (picked.length === 0) return

    const formData = new FormData()
    picked.forEach((file) => formData.append("files[]", file))

    fetch(this.extractUrlValue, {
      method: "POST",
      credentials: "same-origin",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": this.csrfValue
      },
      body: formData
    })
      .then((response) => response.json())
      .then((data) => {
        Array.from(data.documents || []).forEach((doc) => {
          if (doc.error) {
            this.renderAttachmentError(doc)
            return
          }
          this.attachedDocuments.push(doc)
        })
        this.renderAttachments()
      })
      .catch(() => {
        console.log("filesPicked:", this.errorExtractFailedValue)
        // window.alert(this.errorExtractFailedValue)
      })

    event.target.value = ""
  }

  renderAttachments() {
    this.attachmentsTarget.innerHTML = ""
    this.attachedDocuments.forEach((doc, index) => {
      const li = document.createElement("li")
      li.className = "projekt-import-chat__attachment"
      const name = document.createElement("span")
      name.textContent = doc.name
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "projekt-import-chat__attachment-remove"
      remove.textContent = "×"
      remove.addEventListener("click", () => {
        this.attachedDocuments.splice(index, 1)
        this.renderAttachments()
      })
      li.appendChild(name)
      li.appendChild(remove)
      this.attachmentsTarget.appendChild(li)
    })
  }

  renderAttachmentError(doc) {
    const li = document.createElement("li")
    li.className = "projekt-import-chat__attachment projekt-import-chat__attachment--error"
    li.textContent = `${doc.name}: ${doc.error}`
    this.attachmentsTarget.appendChild(li)
  }
}

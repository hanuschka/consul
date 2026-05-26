import { Controller } from "@hotwired/stimulus"

// Chat screen: polls /messages?after=:last_id every 2s, supports mid-chat
// document attach, four command buttons, and the final import overlay.
export default class extends Controller {
  static targets = [
    "messages", "form", "textarea", "sendButton",
    "attachments", "typingIndicator", "overlay", "overlayLabel"
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
    confirmImport: String,
    confirmStartOver: String,
    progressFinalizing: String,
    progressResolving: String,
    progressCreating: String,
    progressGeneratingImage: String,
    errorExtractFailed: String
  }

  connect() {
    this.lastMessageId = this.computeLastMessageId()
    this.attachedDocuments = []
    this.pollTimer = null
    this.statusPollTimer = null
    this.scheduleMessagesPoll()
  }

  disconnect() {
    this.clearPollTimer()
    this.clearStatusPollTimer()
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
    const url = `${this.messagesUrlValue}?after=${this.lastMessageId}`
    fetch(url, {
      credentials: "same-origin",
      headers: { "Accept": "application/json" }
    })
      .then((response) => response.json())
      .then((data) => this.handleMessages(data))
      .catch(() => this.scheduleMessagesPoll())
  }

  handleMessages(data) {
    if (Array.isArray(data.messages)) {
      data.messages.forEach((m) => this.appendOrUpdateMessage(m))
    }

    if (data.ai_chat && data.ai_chat.running) {
      this.typingIndicatorTarget.hidden = false
    } else {
      this.typingIndicatorTarget.hidden = true
    }

    if (data.import) {
      this.handleImportState(data.import)
    } else {
      this.scheduleMessagesPoll()
    }
  }

  appendOrUpdateMessage(m) {
    let node = this.messagesTarget.querySelector(`[data-message-id="${m.id}"]`)

    if (!node) {
      node = document.createElement("div")
      node.className = `projekt-import-chat__message projekt-import-chat__message--${m.role}`
      node.dataset.messageId = String(m.id)
      const author = document.createElement("div")
      author.className = "projekt-import-chat__message-author"
      author.textContent = m.role === "assistant" ? "AI" : "You"
      const body = document.createElement("div")
      body.className = "projekt-import-chat__message-body"
      node.appendChild(author)
      node.appendChild(body)
      this.messagesTarget.insertBefore(node, this.typingIndicatorTarget)
    }

    node.dataset.status = m.status
    const body = node.querySelector(".projekt-import-chat__message-body")
    body.innerHTML = ""
    const text = document.createElement("div")
    text.innerText = m.content || ""
    body.appendChild(text)

    if (m.id > this.lastMessageId) this.lastMessageId = m.id
    this.scrollToBottom()
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  handleImportState(state) {
    if (state.status === "submitting") {
      this.showOverlay(this.progressCreatingValue)
      this.scheduleStatusPoll()
      return
    }

    if (state.status === "completed") {
      this.clearPollTimer()
      this.showOverlay(this.progressCreatingValue)
      window.location.href = `/adm/projekts/${state.projekt_id}/details`
      return
    }

    if (state.status === "failed") {
      this.clearPollTimer()
      this.hideOverlay()
      window.alert(state.error || "")
      this.scheduleMessagesPoll()
      return
    }

    this.scheduleMessagesPoll()
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
        if (data.status === "completed" && data.redirect_path) {
          window.location.href = data.redirect_path
          return
        }
        if (data.status === "failed") {
          this.hideOverlay()
          window.alert(data.error || "")
          return
        }
        this.scheduleStatusPoll()
      })
      .catch(() => this.scheduleStatusPoll())
  }

  showOverlay(label) {
    this.overlayLabelTarget.textContent = label
    this.overlayTarget.hidden = false
  }

  hideOverlay() {
    this.overlayTarget.hidden = true
  }

  submit(event) {
    event.preventDefault()
    const content = this.textareaTarget.value.trim()
    if (!content && this.attachedDocuments.length === 0) return

    this.sendButtonTarget.disabled = true

    const formData = new FormData()
    formData.append("content", content)
    if (this.attachedDocuments.length > 0) {
      formData.append("attached_documents", JSON.stringify(this.attachedDocuments))
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
      .then(() => {
        this.textareaTarget.value = ""
        this.attachedDocuments = []
        this.renderAttachments()
        this.sendButtonTarget.disabled = false
        this.scheduleMessagesPoll()
      })
      .catch(() => {
        this.sendButtonTarget.disabled = false
      })
  }

  textareaKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.submit(event)
    }
  }

  regenerate() {
    this.sendCommand("regenerate")
  }

  summarize() {
    this.sendCommand("summarize")
  }

  startImport() {
    if (!window.confirm(this.confirmImportValue)) return
    this.showOverlay(this.progressFinalizingValue)
    this.sendCommand("import").then((data) => {
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

  sendCommand(name) {
    const formData = new FormData()
    formData.append("name", name)

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
        window.alert(this.errorExtractFailedValue)
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

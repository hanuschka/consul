App.Studio.ContentBlocks.SimpleEditMode.EditPopup = {
  viewportMargin: 12,
  openPopup: null,

  initialize() {
    // Capture phase, so handlers that stop propagation can't swallow it, and
    // pointerdown, so the click that opens a popup can't also dismiss it
    document.addEventListener("pointerdown", this.handlePointerDown.bind(this), true)
  },

  show($popup, anchorElement, placement, onDismiss) {
    const popup = $popup[0]
    const rect = anchorElement.getBoundingClientRect()
    const anchorY = placement === "above" ? rect.top : rect.bottom

    if (this.openPopup && this.openPopup.popup !== popup) {
      this.dismissOpenPopup()
    }

    $popup.css({
      top: window.scrollY + anchorY + "px",
      left: window.scrollX + rect.left + "px",
      display: "block"
    })

    this.keepInsideViewport(popup)
    this.openPopup = { popup, anchorElement, onDismiss }
  },

  keepInsideViewport(popup) {
    const viewportRight = document.documentElement.clientWidth - this.viewportMargin
    const overflow = popup.getBoundingClientRect().right - viewportRight

    if (overflow <= 0) return

    const minLeft = window.scrollX + this.viewportMargin
    const shiftedLeft = parseFloat(popup.style.left) - overflow

    popup.style.left = `${Math.max(minLeft, shiftedLeft)}px`
  },

  hide($popup) {
    $popup.hide()

    if (this.openPopup && this.openPopup.popup === $popup[0]) {
      this.openPopup = null
    }
  },

  handlePointerDown(e) {
    if (!this.openPopup) return
    if (this.keepsPopupOpen(e.target)) return

    this.dismissOpenPopup()
  },

  // The anchor reopens or keeps its own popup; a modal dialog such as the
  // file manager is opened from inside a popup; a target of the root element
  // is a press on the page scrollbar.
  keepsPopupOpen(target) {
    const { popup, anchorElement } = this.openPopup

    return popup.contains(target) ||
      anchorElement.contains(target) ||
      Boolean(target.closest("dialog[open]")) ||
      target === document.documentElement
  },

  dismissOpenPopup() {
    const { onDismiss } = this.openPopup

    this.openPopup = null
    onDismiss()
  }
}

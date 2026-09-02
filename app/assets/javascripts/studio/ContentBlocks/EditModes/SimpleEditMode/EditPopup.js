App.Studio.ContentBlocks.SimpleEditMode.EditPopup = {
  show($popup, anchorElement, placement = "below") {
    const rect = anchorElement.getBoundingClientRect()
    const anchorY = placement === "above" ? rect.top : rect.bottom

    $popup.css({
      top: window.scrollY + anchorY + "px",
      left: window.scrollX + rect.left + "px",
      display: "block"
    })
  },

  hide($popup) {
    $popup.hide()
  }
}

App.ContentBlockEditor.SimpleEditMode.ImageAltEdit = {
  currentImg: null,
  missingAltHint: "Alt-Text fehlt – bitte Bildbeschreibung hinzufügen",

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-img-overlay-alt", this.handleAltButtonClick.bind(this))
    $document.on("click", ".js-content-block-accept-image-alt-edit", this.acceptAltEdit.bind(this))
    $document.on("click", ".js-content-block-cancel-image-alt-edit", this.cancelAltEdit.bind(this))
    $document.on("keydown", ".js-content-block-image-alt-popup", this.handlePopupKeydown.bind(this))
  },

  getPopup() {
    return $(".js-content-block-image-alt-popup");
  },

  getAltInput() {
    return document.querySelector(".js-content-block-image-alt-input");
  },

  getAltButton() {
    return document.querySelector(".js-img-overlay-alt");
  },

  handleAltButtonClick(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    const img = App.ContentBlockEditor.SimpleEditMode.ImageEdit.activeImg
    if (!img) return

    this.currentImg = img

    this.showPopupForImage(img)
  },

  showPopupForImage(img) {
    const rect = img.getBoundingClientRect()

    this.getPopup().css({
      top: window.scrollY + rect.bottom + "px",
      left: window.scrollX + rect.left + "px",
      display: "block"
    })

    const altInput = this.getAltInput()
    altInput.value = (img.getAttribute("alt") || "").trim()

    altInput.focus()
  },

  acceptAltEdit(e) {
    e.preventDefault()

    if (!this.currentImg) return

    const altText = this.getAltInput().value.trim()

    if (altText) {
      this.currentImg.alt = altText
    } else {
      this.currentImg.removeAttribute("alt")
    }

    this.updateAltButtonState(this.currentImg)
    this.hidePopup()
  },

  cancelAltEdit(e) {
    e.preventDefault()

    this.hidePopup()
  },

  handlePopupKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault()
      this.hidePopup()

      return
    }

    if (e.key === "Enter" && (e.ctrlKey || e.metaKey)) {
      e.preventDefault()
      this.acceptAltEdit(e)
    }
  },

  hidePopup() {
    this.getPopup().hide()
    this.getAltInput().value = ""
    this.currentImg = null
  },

  updateAltButtonState(img) {
    const altButton = this.getAltButton()
    const altText = (img.getAttribute("alt") || "").trim()

    if (altText) {
      altButton.classList.remove("-warning")
      altButton.setAttribute("data-hint", altText)
    } else {
      altButton.classList.add("-warning")
      altButton.setAttribute("data-hint", this.missingAltHint)
    }
  },
}

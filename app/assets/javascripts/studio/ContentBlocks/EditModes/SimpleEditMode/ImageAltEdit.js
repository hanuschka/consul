App.Studio.ContentBlocks.SimpleEditMode.ImageAltEdit = {
  currentImg: null,
  altTitle: "Alt-Text",
  missingAltTitle: "Alt-Text fehlt",
  missingAltText: "Bitte fügen Sie eine kurze Bildbeschreibung hinzu.",

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

  getTooltipElement() {
    return document.querySelector(".js-image-edit-overlay rich-tooltip");
  },

  getTooltipContainerElement() {
    return document.querySelector(".js-image-alt-tooltip");
  },

  getTooltipTitleElement() {
    return document.querySelector(".js-image-alt-tooltip-title");
  },

  getTooltipTextElement() {
    return document.querySelector(".js-image-alt-tooltip-text");
  },

  handleAltButtonClick(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    const img = App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.activeImg
    if (!img) return

    this.currentImg = img

    this.hideTooltip()
    this.showPopupForImage(img)
  },

  showPopupForImage(img) {
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show(
      this.getPopup(), this.getAltButton(), "above"
    )

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
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.hide(this.getPopup())
    this.getAltInput().value = ""
    this.currentImg = null
  },

  updateAltButtonState(img) {
    const altButton = this.getAltButton()
    const tooltipContainer = this.getTooltipContainerElement()
    const altText = (img.getAttribute("alt") || "").trim()

    if (!tooltipContainer) return

    if (altText) {
      altButton.classList.remove("-warning")
      altButton.classList.add("-active")
      tooltipContainer.classList.remove("-warning")
      this.getTooltipTitleElement().textContent = this.altTitle
      this.getTooltipTextElement().textContent = altText
    } else {
      altButton.classList.remove("-active")
      altButton.classList.add("-warning")
      tooltipContainer.classList.add("-warning")
      this.getTooltipTitleElement().textContent = this.missingAltTitle
      this.getTooltipTextElement().textContent = this.missingAltText
    }
  },

  hideTooltip() {
    const tooltipElement = this.getTooltipElement()

    if (tooltipElement && tooltipElement.tooltipBody) {
      tooltipElement.hide()
    }
  },
}

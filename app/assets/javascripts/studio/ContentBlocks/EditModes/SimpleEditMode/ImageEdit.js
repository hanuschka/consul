App.Studio.ContentBlocks.SimpleEditMode.ImageEdit = {
  PAN_MIN_OVERFLOW: 1,

  contentBlockImageLoadingState: {},
  activeImg: null,
  overlayEl: null,
  isDragging: false,
  dragState: null,
  isActive: false,
  isPanning: false,
  panState: null,

  initialize() {
    this.buildOverlay()
    this.buildLoadingOverlay()
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on(
      "mouseenter",
      ".-simple-edit-mode .custom-content-block img",
      this.handleImageMouseEnter.bind(this)
    )

    this.overlayEl.addEventListener(
      "mouseleave", this.handleOverlayMouseLeave.bind(this)
    )

    $document.on("click", ".js-img-overlay-change", this.handleChangeClick.bind(this))
    $document.on("click", ".js-img-overlay-crop", this.handleCropClick.bind(this))

    $document.on("mousedown", ".js-img-resize-handle", this.handleResizeStart.bind(this))
    document.addEventListener("mousemove", this.handleResizeMove.bind(this))
    document.addEventListener("mouseup", this.handleResizeEnd.bind(this))

    $document.on("input", ".js-img-overlay-height-input", this.handleHeightInput.bind(this))
    $document.on("click", ".js-img-overlay-height-decrease", this.handleHeightDecrease.bind(this))
    $document.on("click", ".js-img-overlay-height-increase", this.handleHeightIncrease.bind(this))

    $document.on(
      "mousedown",
      ".-simple-edit-mode .custom-content-block img",
      this.handlePanStart.bind(this)
    )
    document.addEventListener("mousemove", this.handlePanMove.bind(this))
    document.addEventListener("mouseup", this.handlePanEnd.bind(this))

    $document.on(
      "dblclick",
      ".-simple-edit-mode .custom-content-block img",
      this.handleImageDoubleClick.bind(this)
    )

    $document.on("click", ".js-img-overlay-recenter", this.handleRecenterClick.bind(this))
  },

  buildOverlay() {
    const overlay = document.createElement("div")
    overlay.className = "js-image-edit-overlay image-edit-overlay js-studio-hide-on-preview"
    overlay.style.display = "none"
    overlay.innerHTML = `
      <div class="image-edit-overlay--height-control">
        <button type="button" class="js-img-overlay-height-decrease" tabindex="-1">
          <i class="fa fas fa-minus"></i>
        </button>
        <input
          type="number"
          class="js-img-overlay-height-input"
          min="30"
        >
        <button type="button" class="js-img-overlay-height-increase" tabindex="-1">
          <i class="fa fas fa-plus"></i>
        </button>
      </div>

      <div class="image-edit-overlay--handle -top-left js-img-resize-handle" data-corner="top-left"></div>
      <div class="image-edit-overlay--handle -top-right js-img-resize-handle" data-corner="top-right"></div>
      <div class="image-edit-overlay--handle -bottom-left js-img-resize-handle" data-corner="bottom-left"></div>
      <div class="image-edit-overlay--handle -bottom-right js-img-resize-handle" data-corner="bottom-right"></div>

      <div class="image-edit-overlay--actions">
        ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
          <button type="button" class="image-edit-overlay--action-button js-img-overlay-change" tabindex="-1">
            <i class="fa fas fa-pencil-alt"></i>
          </button>
        `, {
          title: "Bild ersetzen",
          text: "Wählt ein anderes Bild aus der Mediengalerie und ersetzt das aktuelle.",
          delay: 600
        })}
        ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
          <button type="button" class="image-edit-overlay--action-button js-img-overlay-crop" tabindex="-1">
            <i class="fa fas fa-crop-alt"></i>
          </button>
        `, {
          title: "Zuschnitt umschalten",
          text: "Wechselt zwischen formatfüllendem Zuschnitt und vollständig sichtbarem Bild.",
          note: "Betrifft nur die Darstellung, nicht die Originaldatei.",
          delay: 600
        })}
        ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
          <button type="button" class="image-edit-overlay--action-button -pan-only js-img-overlay-recenter" tabindex="-1">
            <i class="fa fas fa-crosshairs"></i>
          </button>
        `, {
          title: "Ausschnitt zentrieren",
          text: "Setzt die Bildposition wieder in die Mitte zurück.",
          note: "Verfügbar, wenn das zugeschnittene Bild verschoben werden kann.",
          delay: 600
        })}
        <rich-tooltip>
          <button type="button" class="image-edit-overlay--action-button js-img-overlay-alt" tabindex="-1">
            <i class="fa fas fa-comment-dots"></i>
          </button>

          <template>
            <div class="image-alt-tooltip js-image-alt-tooltip">
              <strong class="image-alt-tooltip--title">
                <i class="fa fas fa-check-circle image-alt-tooltip--icon-ok"></i>
                <i class="fa fas fa-exclamation-triangle image-alt-tooltip--icon-warning"></i>
                <span class="js-image-alt-tooltip-title"></span>
              </strong>
              <p class="image-alt-tooltip--text js-image-alt-tooltip-text"></p>
              <div class="image-alt-tooltip--why">
                <span class="image-alt-tooltip--why-label">
                  <i class="fa fas fa-circle-info"></i>
                  Warum Alt-Text?
                </span>
                <p class="image-alt-tooltip--explanation">
                  Wird von Screenreadern vorgelesen und angezeigt, wenn das Bild
                  nicht geladen werden kann. Wichtig für Barrierefreiheit und SEO.
                </p>
              </div>
            </div>
          </template>
        </rich-tooltip>
      </div>
    `

    document.body.appendChild(overlay)
    this.overlayEl = overlay
  },

  buildLoadingOverlay() {
    const loading = document.createElement("div")
    loading.className = "js-image-edit-loading-overlay image-edit-loading-overlay"
    loading.style.display = "none"
    loading.innerHTML = `
      <div class="image-edit-loading-overlay--blur-backdrop"></div>
      <div class="image-edit-loading-overlay--blur js-image-edit-loading-blur"></div>
      <div class="loading-spinner-inline"></div>
    `

    document.body.appendChild(loading)
    this.loadingOverlayEl = loading
  },

  toggleImageControls(contentBlock, enabled) {
    this.isActive = enabled

    if (enabled) {
      this.ensureOverlaysAttached()
    } else {
      this.clearImageCursors(contentBlock)
      this.deactivate()
    }
  },

  clearImageCursors(contentBlock) {
    contentBlock.querySelectorAll("img").forEach((img) => {
      img.style.cursor = ""
    })
  },

  ensureOverlaysAttached() {
    const staleOverlays = document.querySelectorAll(
      ".js-image-edit-overlay, .js-image-edit-loading-overlay"
    );
    staleOverlays.forEach((el) => {
      if (el !== this.overlayEl && el !== this.loadingOverlayEl) {
        el.remove()
      }
    })

    if (!document.body.contains(this.overlayEl)) {
      document.body.appendChild(this.overlayEl)
    }

    if (!document.body.contains(this.loadingOverlayEl)) {
      document.body.appendChild(this.loadingOverlayEl)
    }
  },

  handleImageMouseEnter(e) {
    if (!this.isActive || this.isDragging || this.isPanning) return
    if (e.currentTarget.closest(".js-content-block-element-not-editable")) return

    this.showOverlayForImage(e.currentTarget)
  },

  handleOverlayMouseLeave(_e) {
    if (this.isDragging || this.isPanning) return

    this.hideOverlay()
  },

  showOverlayForImage(img) {
    this.activeImg = img
    const rect = img.getBoundingClientRect()

    Object.assign(this.overlayEl.style, {
      display: "",
      left: `${rect.left + window.scrollX}px`,
      top: `${rect.top + window.scrollY}px`,
      width: `${rect.width}px`,
      height: `${rect.height}px`,
    })

    const heightInput = this.overlayEl.querySelector(".js-img-overlay-height-input")
    heightInput.value = Math.round(rect.height)
    heightInput.max = img.naturalHeight || Math.round(rect.height)

    this.updateCropButtonState(img)
    this.updateMoveControlsState(img)
    App.Studio.ContentBlocks.SimpleEditMode.ImageAltEdit.updateAltButtonState(img)
  },

  hideOverlay() {
    this.overlayEl.style.display = "none"
    this.activeImg = null
  },

  deactivate() {
    this.hideOverlay()
    this.hideLoadingOverlay()
    App.Studio.ContentBlocks.SimpleEditMode.ImageAltEdit.hidePopup()
    App.Studio.ContentBlocks.SimpleEditMode.ImageAltEdit.hideTooltip()
    this.isDragging = false
    this.dragState = null
    this.isPanning = false
    this.panState = null
  },

  updateCropButtonState(img) {
    const cropButton = this.overlayEl.querySelector(".js-img-overlay-crop")

    cropButton.classList.toggle("-active", this.isImageCropped(img))
  },

  isImageCropped(img) {
    return getComputedStyle(img).objectFit === "cover"
  },

  // --- Action buttons ---

  handleChangeClick(e) {
    e.stopPropagation()
    e.stopImmediatePropagation()
    e.preventDefault()

    if (!this.activeImg) return

    const img = this.activeImg
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(img)
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId

    App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog.openForImages(
      (selectedPicture) => {
        this.replaceImage(img, selectedPicture)
      },
      contentBlockId,
      contentBlockWrapper
    )
  },

  handleCropClick(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    if (!this.activeImg) return

    const img = this.activeImg

    if (this.isImageCropped(img)) {
      img.style.objectFit = "contain"
      img.style.margin = "auto"
    } else {
      img.dataset.previousHeight = img.style.height
      img.style.objectFit = "cover"
    }

    this.updateCropButtonState(img)
    this.updateMoveControlsState(img)
  },

  // --- Move inside crop ---

  updateMoveControlsState(img) {
    const pannable = this.canPanImage(img)

    this.overlayEl.classList.toggle("-pannable", pannable)
    img.style.cursor = pannable ? "grab" : "default"
  },

  canPanImage(img) {
    if (!this.isImageCropped(img)) return false

    const overflow = this.getCoverOverflow(img)

    return overflow.x >= this.PAN_MIN_OVERFLOW || overflow.y >= this.PAN_MIN_OVERFLOW
  },

  handlePanStart(e) {
    if (!this.activeImg) return
    if (!this.canPanImage(this.activeImg)) return

    e.preventDefault()

    this.isPanning = true

    const position = this.getObjectPosition(this.activeImg)

    this.panState = {
      startX: e.clientX,
      startY: e.clientY,
      originalX: position.x,
      originalY: position.y,
    }

    document.body.style.cursor = "grabbing"
    document.body.style.userSelect = "none"
  },

  handlePanMove(e) {
    if (!this.isPanning || !this.panState || !this.activeImg) return

    const { startX, startY, originalX, originalY } = this.panState
    const overflow = this.getCoverOverflow(this.activeImg)

    const deltaXPercent = this.pixelDeltaToPercent(e.clientX - startX, overflow.x)
    const deltaYPercent = this.pixelDeltaToPercent(e.clientY - startY, overflow.y)

    this.setObjectPosition(this.activeImg, originalX - deltaXPercent, originalY - deltaYPercent)
  },

  handlePanEnd(_e) {
    if (!this.isPanning) return

    this.isPanning = false
    this.panState = null
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
  },

  handleRecenterClick(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    if (!this.activeImg) return

    this.recenterImage(this.activeImg)
  },

  handleImageDoubleClick(e) {
    if (!this.activeImg) return
    if (!this.canPanImage(e.currentTarget)) return

    this.recenterImage(e.currentTarget)
  },

  recenterImage(img) {
    this.setObjectPosition(img, 50, 50)
  },

  getObjectPosition(img) {
    const raw = img.style.objectPosition || getComputedStyle(img).objectPosition
    const parts = raw.split(" ")

    return {
      x: this.parsePositionValue(parts[0]),
      y: this.parsePositionValue(parts[1]),
    }
  },

  parsePositionValue(value) {
    const parsed = parseFloat(value)

    if (isNaN(parsed)) return 50

    return parsed
  },

  setObjectPosition(img, xPercent, yPercent) {
    const x = Math.round(this.clampPercent(xPercent) * 10) / 10
    const y = Math.round(this.clampPercent(yPercent) * 10) / 10

    img.style.objectPosition = `${x}% ${y}%`
  },

  clampPercent(value) {
    return Math.min(100, Math.max(0, value))
  },

  pixelDeltaToPercent(deltaPx, overflowPx) {
    if (overflowPx <= 0) return 0

    return (deltaPx / overflowPx) * 100
  },

  getCoverOverflow(img) {
    const rect = img.getBoundingClientRect()
    const naturalWidth = img.naturalWidth
    const naturalHeight = img.naturalHeight

    if (!naturalWidth || !naturalHeight) {
      return { x: 0, y: 0 }
    }

    const scale = Math.max(rect.width / naturalWidth, rect.height / naturalHeight)
    const scaledWidth = naturalWidth * scale
    const scaledHeight = naturalHeight * scale

    return {
      x: Math.max(0, scaledWidth - rect.width),
      y: Math.max(0, scaledHeight - rect.height),
    }
  },

  // --- Drag resize ---

  handleResizeStart(e) {
    e.preventDefault()
    if (!this.activeImg) return

    this.isDragging = true
    const rect = this.activeImg.getBoundingClientRect()

    this.dragState = {
      corner: e.currentTarget.dataset.corner,
      startY: e.clientY,
      originalHeight: rect.height,
    }

    document.body.style.cursor = this.getCursorForCorner(e.currentTarget.dataset.corner)
    document.body.style.userSelect = "none"
  },

  handleResizeMove(e) {
    if (!this.isDragging || !this.dragState || !this.activeImg) return

    const { corner, startY, originalHeight } = this.dragState
    const deltaY = e.clientY - startY
    let newHeight

    if (corner === "bottom-right" || corner === "bottom-left") {
      newHeight = originalHeight + deltaY
    } else {
      newHeight = originalHeight - deltaY
    }

    newHeight = Math.max(30, Math.round(newHeight))

    const maxHeight = this.activeImg.naturalHeight
    if (maxHeight > 0) {
      newHeight = Math.min(maxHeight, newHeight)
    }

    this.applyHeight(this.activeImg, newHeight)
    this.showOverlayForImage(this.activeImg)
  },

  handleResizeEnd(_e) {
    if (!this.isDragging) return

    this.isDragging = false
    this.dragState = null
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
  },

  getCursorForCorner(corner) {
    if (corner === "top-left" || corner === "bottom-right") return "nwse-resize"

    return "nesw-resize"
  },

  // --- Height controls ---

  handleHeightInput(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()

    if (!this.activeImg) return

    const newHeight = parseInt(e.currentTarget.value)
    if (isNaN(newHeight)) return

    this.applyHeight(this.activeImg, newHeight)
    this.showOverlayForImage(this.activeImg)
  },

  handleHeightDecrease(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    if (!this.activeImg) return

    const input = this.overlayEl.querySelector(".js-img-overlay-height-input")
    const currentHeight = parseInt(input.value)
    const newHeight = Math.max(30, currentHeight - 10)

    this.applyHeight(this.activeImg, newHeight)
    this.showOverlayForImage(this.activeImg)
  },

  handleHeightIncrease(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    if (!this.activeImg) return

    const input = this.overlayEl.querySelector(".js-img-overlay-height-input")
    const currentHeight = parseInt(input.value)
    const maxHeight = this.activeImg.naturalHeight || currentHeight + 10
    const newHeight = Math.min(maxHeight, currentHeight + 10)

    this.applyHeight(this.activeImg, newHeight)
    this.showOverlayForImage(this.activeImg)
  },

  applyHeight(img, height) {
    img.style.height = `${height}px`
    img.dataset.originalThumbHeight = height
    img.height = height
  },

  // --- Image replacement ---

  incrementImageLoadingCount(contentBlockId) {
    if (!this.contentBlockImageLoadingState[contentBlockId]) {
      this.contentBlockImageLoadingState[contentBlockId] = 0
    }

    this.contentBlockImageLoadingState[contentBlockId] += 1
  },

  decrementImageLoadingCount(contentBlockId) {
    if (!this.contentBlockImageLoadingState[contentBlockId]) return

    this.contentBlockImageLoadingState[contentBlockId] -= 1
  },

  async replaceImage(img, selectedPicture) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(img)
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId

    this.incrementImageLoadingCount(contentBlockId)
    App.Studio.ContentBlocks.SimpleEditMode.toggleLockSaveCancel(contentBlockWrapper, true)

    this.showLoadingOverlay(img, selectedPicture.gallery_thumb_url)

    const customThumbUrl = selectedPicture.custom_thumb_url

    const onImageLoadComplete = () => {
      this.hideLoadingOverlay()
      this.finishImageLoading(img, contentBlockWrapper, contentBlockId)

      img.removeEventListener("load", onImageLoadComplete)
      img.removeEventListener("error", onImageLoadComplete)
    }

    img.addEventListener("load", onImageLoadComplete)
    img.addEventListener("error", onImageLoadComplete)

    this.setImageSrc(img, selectedPicture, customThumbUrl)
  },

  showLoadingOverlay(img, previewUrl) {
    const rect = img.getBoundingClientRect()

    Object.assign(this.loadingOverlayEl.style, {
      display: "flex",
      left: `${rect.left + window.scrollX}px`,
      top: `${rect.top + window.scrollY}px`,
      width: `${rect.width}px`,
      height: `${rect.height}px`,
    })

    const blurEl = this.loadingOverlayEl.querySelector(".js-image-edit-loading-blur")

    if (previewUrl) {
      blurEl.style.backgroundImage = `url(${previewUrl})`
    }
  },

  hideLoadingOverlay() {
    this.loadingOverlayEl.style.display = "none"

    const blurEl = this.loadingOverlayEl.querySelector(".js-image-edit-loading-blur")
    blurEl.style.backgroundImage = ""
  },

  finishImageLoading(img, contentBlockWrapper, contentBlockId) {
    this.decrementImageLoadingCount(contentBlockId)

    img.style.objectFit = "cover"
    img.style.objectPosition = ""

    img.style.height = ""
    img.removeAttribute("height")

    const newHeight = img.clientHeight || img.naturalHeight

    img.height = newHeight
    img.dataset.originalThumbHeight = newHeight
    img.style.height = `${newHeight}px`

    if (this.contentBlockImageLoadingState[contentBlockId] <= 0) {
      App.Studio.ContentBlocks.SimpleEditMode.toggleLockSaveCancel(
        contentBlockWrapper,
        false
      )
    }
  },

  setImageSrc(img, response, imageUrl) {
    img.src = imageUrl
    img.dataset.fullImageUrl = response.url
    img.dataset.pictureId = response.id
    // Only a hint to the source image; may be stale/wrong, never trust as exact.
    img.dataset.imageIdHint = response.id

    if (response.alt_text) {
      img.alt = response.alt_text
    } else {
      img.removeAttribute("alt")
    }

    App.Studio.ContentBlocks.SimpleEditMode.ImageAltEdit.updateAltButtonState(img)

    const glightboxItem = img.closest(".glightbox-disabled")

    if (glightboxItem) {
      glightboxItem.href = response.url
    }
  },
}

App.Studio.ContentBlocks.SimpleEditMode.ImageEdit = {
  PAN_ALLOW_DIRECT_DRAG: true,
  PAN_STEP_PERCENT: 5,

  contentBlockImageLoadingState: {},
  activeImg: null,
  overlayEl: null,
  isDragging: false,
  dragState: null,
  isActive: false,
  isPanning: false,
  panState: null,
  isFocalDragging: false,
  moveModeActive: false,

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

    $document.on(
      "click",
      ".js-img-overlay-pan-up, .js-img-overlay-pan-down, " +
        ".js-img-overlay-pan-left, .js-img-overlay-pan-right",
      this.handlePanButtonClick.bind(this)
    )

    $document.on("mousedown", ".js-img-overlay-focal", this.handleFocalStart.bind(this))
    document.addEventListener("mousemove", this.handleFocalMove.bind(this))
    document.addEventListener("mouseup", this.handleFocalEnd.bind(this))

    $document.on("click", ".js-img-overlay-move", this.handleMoveToggleClick.bind(this))
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

      <div class="js-img-overlay-focal image-edit-overlay--focal-dot"></div>

      <div class="image-edit-overlay--pan-pad">
        <button type="button" class="image-edit-overlay--pan-button -up js-img-overlay-pan-up" data-pan-direction="up" tabindex="-1">
          <i class="fa fas fa-chevron-up"></i>
        </button>
        <button type="button" class="image-edit-overlay--pan-button -left js-img-overlay-pan-left" data-pan-direction="left" tabindex="-1">
          <i class="fa fas fa-chevron-left"></i>
        </button>
        <button type="button" class="image-edit-overlay--pan-button -right js-img-overlay-pan-right" data-pan-direction="right" tabindex="-1">
          <i class="fa fas fa-chevron-right"></i>
        </button>
        <button type="button" class="image-edit-overlay--pan-button -down js-img-overlay-pan-down" data-pan-direction="down" tabindex="-1">
          <i class="fa fas fa-chevron-down"></i>
        </button>
      </div>

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
          <button type="button" class="image-edit-overlay--action-button -crop-only js-img-overlay-move" tabindex="-1">
            <i class="fa fas fa-arrows-alt"></i>
          </button>
        `, {
          title: "Bildausschnitt verschieben",
          text: "Aktiviert den Verschiebe-Modus: Ziehe das Bild, um den sichtbaren Ausschnitt zu wählen.",
          note: "Nur verfügbar, wenn der formatfüllende Zuschnitt aktiv ist.",
          delay: 600
        })}
        ${App.Studio.Projekt.templateFunctions.studioControlTooltip(`
          <button type="button" class="image-edit-overlay--action-button -crop-only js-img-overlay-recenter" tabindex="-1">
            <i class="fa fas fa-crosshairs"></i>
          </button>
        `, {
          title: "Ausschnitt zentrieren",
          text: "Setzt die Bildposition wieder in die Mitte zurück.",
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

  toggleImageControls(_contentBlock, enabled) {
    this.isActive = enabled

    if (enabled) {
      this.ensureOverlaysAttached()
    } else {
      this.deactivate()
    }
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
    if (!this.isActive || this.isDragging || this.isPanning || this.isFocalDragging) return
    if (e.currentTarget.closest(".js-content-block-element-not-editable")) return

    this.showOverlayForImage(e.currentTarget)
  },

  handleOverlayMouseLeave(_e) {
    if (this.isDragging || this.isPanning || this.isFocalDragging) return

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
    this.updateFocalDotPosition(img)
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
    this.isFocalDragging = false
    this.moveModeActive = false
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
    this.updateFocalDotPosition(img)
  },

  // --- Move inside crop ---

  updateMoveControlsState(img) {
    const cropped = this.isImageCropped(img)

    this.overlayEl.classList.toggle("-croppable", cropped)

    if (!cropped) {
      this.moveModeActive = false
      this.overlayEl.classList.remove("-move-mode")
      img.style.cursor = ""

      return
    }

    const moveButton = this.overlayEl.querySelector(".js-img-overlay-move")
    moveButton.classList.toggle("-active", this.moveModeActive)
    this.overlayEl.classList.toggle("-move-mode", this.moveModeActive)

    const draggable = this.PAN_ALLOW_DIRECT_DRAG || this.moveModeActive
    img.style.cursor = draggable ? "grab" : ""
  },

  handlePanStart(e) {
    if (!this.activeImg) return
    if (!this.isImageCropped(this.activeImg)) return
    if (!this.PAN_ALLOW_DIRECT_DRAG && !this.moveModeActive) return

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
    this.updateFocalDotPosition(this.activeImg)
  },

  handlePanEnd(_e) {
    if (!this.isPanning) return

    this.isPanning = false
    this.panState = null
    document.body.style.cursor = ""
    document.body.style.userSelect = ""
  },

  handlePanButtonClick(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    if (!this.activeImg) return

    const direction = e.currentTarget.dataset.panDirection
    const position = this.getObjectPosition(this.activeImg)
    const step = this.PAN_STEP_PERCENT

    if (direction === "up") position.y -= step
    if (direction === "down") position.y += step
    if (direction === "left") position.x -= step
    if (direction === "right") position.x += step

    this.setObjectPosition(this.activeImg, position.x, position.y)
    this.updateFocalDotPosition(this.activeImg)
  },

  handleFocalStart(e) {
    e.preventDefault()
    e.stopPropagation()

    if (!this.activeImg) return

    this.isFocalDragging = true
    document.body.style.userSelect = "none"
  },

  handleFocalMove(e) {
    if (!this.isFocalDragging || !this.activeImg) return

    const rect = this.activeImg.getBoundingClientRect()
    const xPercent = ((e.clientX - rect.left) / rect.width) * 100
    const yPercent = ((e.clientY - rect.top) / rect.height) * 100

    this.setObjectPosition(this.activeImg, xPercent, yPercent)
    this.updateFocalDotPosition(this.activeImg)
  },

  handleFocalEnd(_e) {
    if (!this.isFocalDragging) return

    this.isFocalDragging = false
    document.body.style.userSelect = ""
  },

  handleMoveToggleClick(e) {
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

    if (!this.activeImg) return

    this.moveModeActive = !this.moveModeActive
    this.updateMoveControlsState(this.activeImg)
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
    if (!this.isImageCropped(e.currentTarget)) return

    this.recenterImage(e.currentTarget)
  },

  recenterImage(img) {
    this.setObjectPosition(img, 50, 50)
    this.updateFocalDotPosition(img)
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

  updateFocalDotPosition(img) {
    const focalDot = this.overlayEl.querySelector(".js-img-overlay-focal")
    const position = this.getObjectPosition(img)

    focalDot.style.left = `${position.x}%`
    focalDot.style.top = `${position.y}%`
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

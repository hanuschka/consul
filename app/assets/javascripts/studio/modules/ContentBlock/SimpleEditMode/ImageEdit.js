App.ContentBlockEditor.SimpleEditMode.ImageEdit = {
  contentBlockImageLoadingState: {},
  activeImg: null,
  overlayEl: null,
  isDragging: false,
  dragState: null,
  isActive: false,

  initialize() {
    this.buildOverlay()
    this.buildLoadingOverlay()
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on(
      "mouseenter",
      ".-simple-edit-mode .projekt-content-block img",
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
  },

  buildOverlay() {
    const overlay = document.createElement("div")
    overlay.className = "js-image-edit-overlay image-edit-overlay js-studio-hide-on-preview"
    overlay.style.display = "none"
    overlay.innerHTML = `
      <div class="image-edit-overlay--height-control">
        <button type="button" class="js-img-overlay-height-decrease">
          <i class="fa fas fa-minus"></i>
        </button>
        <input
          type="number"
          class="js-img-overlay-height-input"
          min="30"
        >
        <button type="button" class="js-img-overlay-height-increase">
          <i class="fa fas fa-plus"></i>
        </button>
      </div>

      <div class="image-edit-overlay--handle -top-left js-img-resize-handle" data-corner="top-left"></div>
      <div class="image-edit-overlay--handle -top-right js-img-resize-handle" data-corner="top-right"></div>
      <div class="image-edit-overlay--handle -bottom-left js-img-resize-handle" data-corner="bottom-left"></div>
      <div class="image-edit-overlay--handle -bottom-right js-img-resize-handle" data-corner="bottom-right"></div>

      <div class="image-edit-overlay--actions">
        <button type="button" class="image-edit-overlay--action-button js-img-overlay-change" data-hint="Bild ändern">
          <i class="fa fas fa-pencil-alt"></i>
        </button>
        <button type="button" class="image-edit-overlay--action-button js-img-overlay-crop" data-hint="Bildzuschnitt umschalten">
          <i class="fa fas fa-crop-alt"></i>
        </button>
        <rich-tooltip>
          <button type="button" class="image-edit-overlay--action-button js-img-overlay-alt">
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
    if (!this.isActive || this.isDragging) return

    this.showOverlayForImage(e.currentTarget)
  },

  handleOverlayMouseLeave(_e) {
    if (this.isDragging) return

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
    App.ContentBlockEditor.SimpleEditMode.ImageAltEdit.updateAltButtonState(img)
  },

  hideOverlay() {
    this.overlayEl.style.display = "none"
    this.activeImg = null
  },

  deactivate() {
    this.hideOverlay()
    this.hideLoadingOverlay()
    App.ContentBlockEditor.SimpleEditMode.ImageAltEdit.hidePopup()
    App.ContentBlockEditor.SimpleEditMode.ImageAltEdit.hideTooltip()
    this.isDragging = false
    this.dragState = null
  },

  updateCropButtonState(img) {
    const cropButton = this.overlayEl.querySelector(".js-img-overlay-crop")
    const isCropped = getComputedStyle(img).objectFit === "cover"

    if (isCropped) {
      cropButton.classList.add("-active")
    } else {
      cropButton.classList.remove("-active")
    }
  },

  // --- Action buttons ---

  handleChangeClick(e) {
    e.stopPropagation()
    e.stopImmediatePropagation()
    e.preventDefault()

    if (!this.activeImg) return

    const img = this.activeImg
    const { contentBlockWrapper } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(img)
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId

    App.ContentBlockEditor.SimpleEditMode.FileManagerDialog.openForImages(
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
    const isCropped = getComputedStyle(img).objectFit === "cover"

    if (isCropped) {
      img.style.objectFit = "contain"
      img.style.margin = "auto"
    } else {
      img.dataset.previousHeight = img.style.height
      img.style.objectFit = "cover"
    }

    this.updateCropButtonState(img)
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
    const { contentBlockWrapper } = App.ContentBlockEditor.DomHelpers.getContentBlockAndWrapper(img)
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId

    this.incrementImageLoadingCount(contentBlockId)
    App.ContentBlockEditor.SimpleEditMode.toggleLockSaveCancel(contentBlockWrapper, true)

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

    img.style.height = ""
    img.removeAttribute("height")

    const newHeight = img.clientHeight || img.naturalHeight

    img.height = newHeight
    img.dataset.originalThumbHeight = newHeight
    img.style.height = `${newHeight}px`

    if (this.contentBlockImageLoadingState[contentBlockId] <= 0) {
      App.ContentBlockEditor.SimpleEditMode.toggleLockSaveCancel(
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

    App.ContentBlockEditor.SimpleEditMode.ImageAltEdit.updateAltButtonState(img)

    const glightboxItem = img.closest(".glightbox-disabled")

    if (glightboxItem) {
      glightboxItem.href = response.url
    }
  },
}

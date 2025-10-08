ProjektStudio.ContentBlockSimpleEdit.ImageEdit = {
  contentBlockImageLoadingState: {},
  currentImg: null,
  currentImageWrapper: null,

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndWrapper = ProjektStudio.ContentBlocks.getContentBlockAndWrapper.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-image-change-button", this.openDialog.bind(this));
  },

  toggleImageControls(contentBlock, enabled) {
    if (enabled) {
      contentBlock
        .querySelectorAll("img")
        .forEach((img) => {
          this.wrapImageWithControls(img)
        })
    } else {
      contentBlock
        .querySelectorAll(".js-content-block-image-wrapper")
        .forEach((imgWrapper) => {
          this.removeImageControls(imgWrapper)
        })
    }
  },

  incrementImageLoadingCount(contentBlockId) {
    if (!this.contentBlockImageLoadingState[contentBlockId]) {
      this.contentBlockImageLoadingState[contentBlockId] = 0;
    }

    this.contentBlockImageLoadingState[contentBlockId] += 1
  },

  decrementImageLoadingCount(contentBlockId) {
    if (!this.contentBlockImageLoadingState[contentBlockId]) {
      return
    }

    this.contentBlockImageLoadingState[contentBlockId] -= 1
  },

  wrapImageWithControls(img) {
    const imageWrapper = document.createElement("div")
    imageWrapper.classList.add("content-block-image-wrapper", "js-content-block-image-wrapper")

    const smallButton = img.height < 120;
    const borderRadius = getComputedStyle(img).borderRadius;

    img.parentNode.insertBefore(imageWrapper, img);
    imageWrapper.appendChild(img);
    imageWrapper.insertAdjacentHTML(
      "beforeend",
      `
        <div
          style="border-radius: ${borderRadius}"
          class="content-block-image-loading-overlay"
        >
          <div class="loading-spinner-inline"></div>
        </div>
        <button
          type="button"
          class="content-block-image-change-button image-change-button js-content-block-image-change-button  ${smallButton ? '-small' : ''}">
            <i class="fa fas fa-pencil-alt"></i>
        </button>
      `
    );
  },

  removeImageControls(imgWrapper) {
    const img = imgWrapper.querySelector("img")

    imgWrapper.parentNode.insertBefore(img, imgWrapper);
    imgWrapper.remove();
  },

  openDialog(e) {
    e.stopPropagation()
    e.stopImmediatePropagation()
    e.preventDefault()

    const wrapper = e.currentTarget.parentElement;
    const img = wrapper.querySelector("img")

    // Store current image reference
    this.currentImg = img;
    this.currentImageWrapper = wrapper;

    // Get content block context for loading state tracking
    const { contentBlockWrapper } = this.getContentBlockAndWrapper(img);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    // Open the image gallery dialog with callback and content block context
    ProjektStudio.ContentBlockSimpleEdit.ImageGalleryDialog.openDialog(
      (selectedImage) => {
        this.replaceImage(selectedImage);
      },
      contentBlockId,
      contentBlockWrapper
    );
  },

  replaceImage(selectedImage) {
    console.log("replaceImage", selectedImage)

    if (!selectedImage || !this.currentImg || !this.currentImageWrapper) {
      return;
    }

    const img = this.currentImg;
    const imageWrapper = this.currentImageWrapper;
    const { contentBlockWrapper } = this.getContentBlockAndWrapper(img);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    // Lock the content block and track loading state
    this.incrementImageLoadingCount(contentBlockId);
    ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(contentBlockWrapper, true)

    imageWrapper.classList.add("-loading")

    // Create blurred preview overlay
    const previewUrl = selectedImage.previewUrl || selectedImage.thumb_url || selectedImage.custom_thumb_url;
    if (previewUrl) {
      const blurOverlay = document.createElement('div');
      blurOverlay.className = 'content-block-image-blur-overlay';
      blurOverlay.style.backgroundImage = `url(${previewUrl})`;
      imageWrapper.appendChild(blurOverlay);
    }

    const onImageLoadComplete = () => {
      $(imageWrapper).find('.content-block-image-blur-overlay').remove();

      this.finishImageLoading(imageWrapper, contentBlockWrapper, contentBlockId);

      img.removeEventListener('load', onImageLoadComplete);
      img.removeEventListener('error', onImageLoadComplete);
    };

    // Add event listeners
    img.addEventListener('load', onImageLoadComplete);
    img.addEventListener('error', onImageLoadComplete);

    // Set the actual image source directly
    this.setImageSrc(img, selectedImage);

    this.currentImg = null;
    this.currentImageWrapper = null;
  },

  finishImageLoading(imageWrapper, contentBlockWrapper, contentBlockId) {
    imageWrapper.classList.remove("-loading")
    this.decrementImageLoadingCount(contentBlockId)

    // If all images in this content block are done loading, unlock the save/cancel buttons
    console.log(this.contentBlockImageLoadingState)
    if (this.contentBlockImageLoadingState[contentBlockId] <= 0) {
      ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(
        contentBlockWrapper,
        false
      )
    }
  },

  setImageSrc(img, response) {
    img.src = response.custom_thumb_url || response.url
    img.dataset.fullImageUrl = response.url
    img.dataset.pictureId = response.id

    const glightboxItem = img.closest(".glightbox-disabled");

    if (glightboxItem) {
      glightboxItem.href = response.url
    }
  },
}

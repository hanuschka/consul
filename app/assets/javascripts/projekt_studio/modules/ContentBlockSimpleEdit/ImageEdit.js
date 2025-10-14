ProjektStudio.ContentBlockSimpleEdit.ImageEdit = {
  contentBlockImageLoadingState: {},
  currentImg: null,

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndWrapper = ProjektStudio.ContentBlocks.getContentBlockAndWrapper.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-image-change-button", this.openaImageGallery.bind(this));
    $document.on("click", ".js-content-block-image-crop-button", this.toggleCropImage.bind(this));
    $document.on("input", ".js-content-block-image-height-range", this.handleHeightRangeChange.bind(this));
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
    const computedStyle = getComputedStyle(img);
    const borderRadius = computedStyle.borderRadius;
    const hasObjectFitContain = computedStyle.objectFit === "contain";

    img.parentNode.insertBefore(imageWrapper, img);
    imageWrapper.appendChild(img);

    const showCropButton = true;

    const cropButton = showCropButton ? `
      <button
        type="button"
        class="content-block-image-crop-button image-change-button js-content-block-image-crop-button ${smallButton ? '-small' : ''} ${this.isImageCropped(img) ? '-active' : ''}">
          <i class="fa fas fa-crop-alt"></i>
      </button>
    ` : '';

    const dimensionControls = img.dataset.studioCrop === 'true' ? `
      <div class="content-block-image-dimension-controls">
        <label>Height:</label>
        <input
          type="range"
          class="js-content-block-image-height-range"
          min="200"
          max="${img.dataset.originalThumbHeight || img.clientHeight}"
          value="${img.clientHeight}"
        >
        <span class="dimension-value">${img.clientHeight}px</span>
      </div>
    ` : '';

    imageWrapper.insertAdjacentHTML(
      "beforeend",
      `
        <div
          style="border-radius: ${borderRadius}"
          class="content-block-image-loading-overlay"
        >
          <div class="content-block-image-loading-overlay-blur-backdrop"></div>
          <div class="content-block-image-loading-overlay-blur"></div>
          <div class="loading-spinner-inline"></div>
        </div>
        <button
          type="button"
          class="content-block-image-change-button image-change-button js-content-block-image-change-button  ${smallButton ? '-small' : ''}">
            <i class="fa fas fa-pencil-alt"></i>
        </button>
        ${cropButton}
        ${dimensionControls}
      `
    );
  },

  removeImageControls(imgWrapper) {
    const img = imgWrapper.querySelector("img")

    imgWrapper.parentNode.insertBefore(img, imgWrapper);
    imgWrapper.remove();
  },

  openaImageGallery(e) {
    const wrapper = e.currentTarget.parentElement;
    this.currentImg = wrapper.querySelector("img")

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(this.currentImg);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    ProjektStudio.ContentBlockSimpleEdit.ImageGalleryDialog.openDialog(
      (selectedPicture) => {
        this.replaceImage(selectedPicture);
      },
      contentBlockId,
      contentBlockWrapper
    );
  },

  toggleCropImage(e) {
    const button = e.currentTarget;
    const wrapper = button.parentElement;
    const img = wrapper.querySelector("img")

    if (this.isImageCropped(img)) {
      button.classList.remove("-active");
      img.style.objectFit = "contain";
      // img.dataset.previousMargin = img.style.margin
      // img.dataset.previousDisplay = img.style.display
      // img.style.display = "block"
      img.style.width = "auto"
      img.style.margin = "auto"
      img.style.height = img.dataset.previousHeight || "auto"
    } else {
      button.classList.add("-active");
      img.dataset.previousHeight = img.style.height
      img.style.objectFit = "cover";
      img.style.width = "100%"

      if (img.dataset.cropHeight) {
        console.log('set crop height', img.dataset.cropHeight)
        img.style.height = img.dataset.cropHeight
      }
      // img.style.margin = img.dataset.previousMargin
      // img.style.display = img.dataset.previousDisplay
    }
  },
  // toggleCropImage(e) {
  //   const button = e.currentTarget;
  //   const wrapper = button.parentElement;
  //   const img = wrapper.querySelector("img")
  //   const elementStyles = getComputedStyle(img)

  //   const defaultAspectRatio = img.dataset.defaultAspectRatio
  //   const defaultHeight = img.dataset.defaultHeight

  //   if (this.isImageCropped(img)) {
  //     button.classList.remove("-active");
  //     // img.dataset.defaultAspectRatio = img.style.aspectRatio
  //     img.dataset.defaultHeight = img.style.height
  //     img.style.aspectRatio = ""
  //     img.style.height = "auto"
  //     img.style.width = "auto"

  //   } else if (defaultAspectRatio && defaultAspectRatio.length > 0) {
  //     button.classList.add("-active");
  //     img.style.aspectRatio = defaultAspectRatio
  //   } else if (defaultHeight && defaultHeight.length > 0) {
  //     button.classList.add("-active");
  //     img.style.height = defaultHeight
  //   }

  //   img.scrollIntoView({
  //     block: "center", inline: "nearest"
  //   })
  // },

  isImageCropped(img) {
    return img.style.objectFit === "cover"
  },

  async replaceImage(selectedPicture) {
    const img = this.currentImg;
    const imageWrapper = this.getImageWrapper(img)
    const { contentBlockWrapper } = this.getContentBlockAndWrapper(img);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    // Lock the content block and track loading state
    this.incrementImageLoadingCount(contentBlockId);
    ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(contentBlockWrapper, true)

    img.style.height = "auto"
    imageWrapper.classList.add("-loading")

    const blurOverlay = imageWrapper.querySelector('.content-block-image-loading-overlay-blur');
    const previewUrl = selectedPicture.gallery_thumb_url;

    blurOverlay.style.backgroundImage = `url(${previewUrl})`;

    // const thumbResponse = await this.fetchCustomThumbVersionOfPicture(
    //   selectedPicture.id,
    //   img.clientWidth + 50
    // )
    // const customThumbUrl = thumbResponse['custom_thumb_url']
    const customThumbUrl = selectedPicture['custom_thumb_url']

    const onImageLoadComplete = () => {
      if (blurOverlay) {
        blurOverlay.style.backgroundImage = '';
        imageWrapper.classList.remove("-loading")
      }

      this.finishImageLoading(img, imageWrapper, contentBlockWrapper, contentBlockId);

      img.removeEventListener('load', onImageLoadComplete);
      img.removeEventListener('error', onImageLoadComplete);
    };

    img.addEventListener('load', onImageLoadComplete);
    img.addEventListener('error', onImageLoadComplete);

    this.setImageSrc(
      img,
      selectedPicture,
      customThumbUrl
    );

    this.currentImg = null;
  },

  // async fetchCustomThumbVersionOfPicture(pictureId, width) {
  //   return await $.ajax({
  //     url: `/ckeditor/pictures/${pictureId}/custom_thumb_url`,
  //     method: "GET",
  //     headers: {
  //       'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
  //     },
  //     data: { width: width },
  //     responseType: "json"
  //   })
  // },

  finishImageLoading(img, imageWrapper, contentBlockWrapper, contentBlockId) {
    imageWrapper.classList.remove("-loading")
    this.decrementImageLoadingCount(contentBlockId)

    img.height = "auto"
    img.dataset.originalThumbHeight = img.clientHeight;

    const range = document.querySelector(".js-content-block-image-height-range")

    if (range) {
      range.max = img.clientHeight
      range.value = img.clientHeight
      range.nextElementSibling.innerHTML = `${img.clientHeight}px`
    }

    // If all images in this content block are done loading, unlock the save/cancel buttons
    if (this.contentBlockImageLoadingState[contentBlockId] <= 0) {
      ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(
        contentBlockWrapper,
        false
      )
    }
  },

  setImageSrc(img, response, imageUrl) {
    img.src = imageUrl
    img.dataset.fullImageUrl = response.url
    img.dataset.pictureId = response.id

    const glightboxItem = img.closest(".glightbox-disabled");

    if (glightboxItem) {
      glightboxItem.href = response.url
    }
  },

  getImageWrapper(img) {
    return img.parentElement;
  },

  handleHeightRangeChange(e) {
    const range = e.currentTarget;
    const wrapper = range.closest(".js-content-block-image-wrapper");
    const img = wrapper.querySelector("img");
    const valueSpan = range.parentElement.querySelector(".dimension-value");

    const newHeight = parseInt(range.value);
    valueSpan.textContent = `${newHeight}px`;

    img.style.height = `${newHeight}px`;
  }
}

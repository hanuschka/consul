ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit = {
  contentBlockImageLoadingState: {},
  currentImg: null,

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-image-change-button", this.openaImageGallery.bind(this));
    $document.on("click", ".js-content-block-image-crop-button", this.toggleCropImage.bind(this));
    $document.on("input", ".js-content-block-image-height-input", this.handleHeightInputChange.bind(this));
    $document.on("click", ".js-content-block-image-height-decrease", this.decreaseHeight.bind(this));
    $document.on("click", ".js-content-block-image-height-increase", this.increaseHeight.bind(this));
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

    img.parentNode.insertBefore(imageWrapper, img);
    imageWrapper.appendChild(img);

    const showCropButton = true;

    const cropButton = `
      <button
        type="button"
        class="content-block-image-control-button content-block-image-crop-button image-change-button js-content-block-image-crop-button ${smallButton ? '-small' : ''} ${this.isImageCropped(img) ? '-active' : ''}">
          <i class="fa fas fa-crop-alt"></i>
      </button>
    `;

    // const dimensionControls = img.dataset.studioResize === 'true' ? `
    const dimensionControls = `
      <div class="content-block-image-height-control">
        <button type="button" class="js-content-block-image-height-decrease"><i class="fa fas fa-minus"></i></button>
        <input
          type="number"
          class="js-content-block-image-height-input"
          min="200"
          max="${img.naturalHeight || img.clientHeight || img.dataset.originalThumbHeight}"
          value="${img.clientHeight}"
        >
        <button type="button" class="js-content-block-image-height-increase"><i class="fa fas fa-plus"></i></button>
      </div>
    `

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
        ${dimensionControls}
        <div class="content-block-image-control-buttons">
          <button
            type="button"
            class="content-block-image-control-button content-block-image-change-button image-change-button js-content-block-image-change-button  ${smallButton ? '-small' : ''}"
          >
            <i class="fa fas fa-pencil-alt"></i>
          </button>
          ${cropButton}
        </div>
      `
    );
  },

  removeImageControls(imgWrapper) {
    const img = imgWrapper.querySelector("img")

    imgWrapper.parentNode.insertBefore(img, imgWrapper);
    imgWrapper.remove();
  },

  openaImageGallery(e) {
    const wrapper = this.getImageWrapper(e.currentTarget);
    this.currentImg = wrapper.querySelector("img")

    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(this.currentImg);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    ProjektStudio.ContentBlock.SimpleEditMode.ImageGalleryDialog.openDialog(
      (selectedPicture) => {
        this.replaceImage(selectedPicture);
      },
      contentBlockId,
      contentBlockWrapper
    );
  },

  toggleCropImage(e) {
    e.preventDefault()
    e.stopPropagation()

    const button = e.currentTarget;
    const wrapper = this.getImageWrapper(button);
    const img = wrapper.querySelector("img")

    if (this.isImageCropped(img)) {
      img.style.objectFit = "contain";
      img.style.margin = "auto"
    } else {
      img.dataset.previousHeight = img.style.height
      img.style.objectFit = "cover";
    }

    this.toggleCropImageButton(img, button)
  },

  toggleCropImageButton(img, button) {
    if (this.isImageCropped(img)) {
      button.classList.add("-active");
    } else {
      button.classList.remove("-active");
    }
  },

  isImageCropped(img) {
    console.log("isImageCropped", getComputedStyle(img).objectFit)
    return getComputedStyle(img).objectFit === "cover"
  },

  async replaceImage(selectedPicture) {
    const img = this.currentImg;
    const imageWrapper = this.getImageWrapper(img)
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(img);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    // Lock the content block and track loading state
    this.incrementImageLoadingCount(contentBlockId);
    ProjektStudio.ContentBlock.SimpleEditMode.toggleLockSaveCancel(contentBlockWrapper, true)

    // img.style.height = "auto"
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

    // const currentObjectFit = getComputedStyle(img).objectFit;
    // if (currentObjectFit === "fill" || currentObjectFit === "contain") {
      img.style.objectFit = "cover"
      this.toggleCropImageButton(img, imageWrapper.querySelector(".js-content-block-image-crop-button"))
    // }
    // img.style.height = ""
    img.height = img.clientHeight
    img.dataset.originalThumbHeight = img.clientHeight;
    img.style.height = `${img.clientHeight}px`

    const heightInput = imageWrapper.querySelector(".js-content-block-image-height-input")

    if (heightInput) {
      heightInput.max = img.naturalHeight
      heightInput.value = img.clientHeight
    }

    // If all images in this content block are done loading, unlock the save/cancel buttons
    if (this.contentBlockImageLoadingState[contentBlockId] <= 0) {
      ProjektStudio.ContentBlock.SimpleEditMode.toggleLockSaveCancel(
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

  handleHeightInputChange(e) {
    const input = e.currentTarget;
    const wrapper = input.closest(".js-content-block-image-wrapper");
    const img = wrapper.querySelector("img");

    const newHeight = parseInt(input.value);

    img.style.height = `${newHeight}px`;
    img.dataset.originalThumbHeight = newHeight
    img.height = newHeight
  },

  decreaseHeight(e) {
    const button = e.currentTarget;
    const wrapper = button.closest(".js-content-block-image-wrapper");
    const img = wrapper.querySelector("img");
    const input = wrapper.querySelector(".js-content-block-image-height-input");

    const currentHeight = parseInt(input.value);
    const newHeight = currentHeight - 10;

    input.value = newHeight;

    img.style.height = `${newHeight}px`;
    img.dataset.originalThumbHeight = newHeight
    img.height = newHeight
  },

  increaseHeight(e) {
    const button = e.currentTarget;
    const wrapper = button.closest(".js-content-block-image-wrapper");
    const img = wrapper.querySelector("img");
    const input = wrapper.querySelector(".js-content-block-image-height-input");

    const currentHeight = parseInt(input.value);
    // const maxHeight = input.getAttribute("max")
    const maxHeight = img.naturalHeight;
    const newHeight = Math.min(maxHeight, currentHeight + 10);

    input.value = newHeight;
    img.style.height = `${newHeight}px`;
    img.dataset.originalThumbHeight = newHeight
    img.height = newHeight
  },

  getImageWrapper(element) {
    return element.closest(".js-content-block-image-wrapper");
  }
}

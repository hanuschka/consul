ProjektStudio.ContentBlockSimpleEdit.ImageEdit = {
  initialize() {
    this.initEventListeners()
    this.getContentBlockAndWrapper = ProjektStudio.ContentBlocks.getContentBlockAndWrapper.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-image-change-button", this.changeImage.bind(this));
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
          const img = imgWrapper.querySelector("img")
          imgWrapper.outerHTML = img.outerHTML
        })
    }
  },

  wrapImageWithControls(img) {
    const imageWrapper = document.createElement("div")
    imageWrapper.classList.add("content-block-image-wrapper", "js-content-block-image-wrapper")

    const smallButton = img.height < 120;
    const borderRadius = getComputedStyle(img).borderRadius;

    imageWrapper.innerHTML = `
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
      ${img.outerHTML}
    `

    img.outerHTML = imageWrapper.outerHTML;
  },

  changeImage(e) {
    e.stopPropagation()
    e.stopImmediatePropagation()
    e.preventDefault()

    const wrapper = e.currentTarget.parentElement;
    const img = wrapper.querySelector("img")
    const fileInput = document.querySelector(".js-content-block-image-change-input")
    fileInput.click()

    document.body.addEventListener('change', (e) => {
      this.uploadImage(e, img, wrapper)
    }, { once: true });
  },

  uploadImage(e, img, imageWrapper) {
    const file = e.target.files && e.target.files[0];
    if (!file) return;

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(img)

    ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(contentBlockWrapper, true)

    imageWrapper.classList.add("-loading")
    const sliderContainer = imageWrapper.closest('.orbit-container')
    const isSlider = !!sliderContainer;

    const reader = new FileReader();
    reader.onload = (evt) => { img.setAttribute('src', evt.target.result); };
    reader.readAsDataURL(file);

    const formData = new FormData();
    formData.append('upload', file);
    formData.append('thumb_width', img.width + 50)
    formData.append('thumb_height', img.height + 50)

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    $.ajax({
      method: 'POST',
      url: '/ckeditor/pictures',
      headers: {
        'X-CSRF-TOKEN': csrfToken,
      },
      data: formData,
      processData: false,
      contentType: false,
    })
      .then((response) => {
        this.handleImageUploaded(img, response)
      })
      .always(() => {
        img.addEventListener("load", () => {
          this.toggleLockForImage(imageWrapper, contentBlockWrapper)
        }, { once: true })
      })
  },

  toggleLockForImage(imageWrapper, contentBlockWrapper) {
    imageWrapper.classList.remove("-loading")
    ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(contentBlockWrapper, false)
  },

  handleImageUploaded(img, response) {
    const previousPictureId = img.dataset.pictureId;
    img.src = response.custom_thumb_url
    img.dataset.fullImageUrl = response.url
    img.dataset.pictureId = response.id

    const glightboxItem = img.closest(".glightbox-disabled");

    if (glightboxItem) {
      glightboxItem.href = response.url
    }

    if (previousPictureId && previousPictureId.length > 0) {
      const csrfToken = $('meta[name="csrf-token"]').attr('content');

      $.ajax({
        method: 'DELETE',
        url: `/ckeditor/pictures/${previousPictureId}`,
        headers: {
          'X-CSRF-TOKEN': csrfToken,
        },
      })
    }
  },
}

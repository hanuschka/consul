ProjektStudio.Banner = {
  initialized: false,
  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-projekt-banner-text-edit-button", this.turnOnTextEdit.bind(this));
    $document.on("click", ".js-projekt-banner--text-edit-cancel", this.cancelTextEdit.bind(this));
    $document.on("click", ".js-projekt-banner--text-edit-save", this.saveEditedText.bind(this));
    $document.on("change", ".js-projekt-banner--image-upload-input", this.updateTitleImage.bind(this));
    // $document.on("change", ".js-projekt-banner--image-upload-input", this.handleInputType.bind(this));
    $document.on("click", ".js-projekt-banner--image-delete-button", this.deleteTitleImage.bind(this));
  },

  handleInputType() {
    editor.addEventListener('input', () => {
      editor.innerHTML = editor.innerHTML.replace(/<br\s*\/?>/gi, ' ');
    });
  },

  turnOnTextEdit(e) {
    const {
      container, field
    } = this.getFieldElementsForButton(e.currentTarget)

    container.classList.add("-text-edit-mode")
    container.dataset.originalFieldHtml = field.innerHTML.trim();

    field.firstElementChild.contentEditable = "plaintext-only"
    ProjektStudio.utils.focusContentEditableElement(field.firstElementChild)
  },

  cancelTextEdit(e) {
    const {
      container, field
    } = this.getFieldElementsForButton(e.currentTarget)

    container.classList.remove("-text-edit-mode")
    field.firstElementChild.contentEditable = false
    field.innerHTML = container.dataset.originalFieldHtml;
  },

  getFieldElementsForButton(button) {
    const container = button.closest(".js-projekt-banner--edit-field-container")
    console.log({button, container})
    const field = container.querySelector(".js-projekt-banner--edit-field-content")

    return { button, container, field }
  },

  saveEditedText(e) {
    const { container, field } = this.getFieldElementsForButton(e.currentTarget)

    if (container.classList.contains("-text-edit-mode")) {
      container.classList.remove("-text-edit-mode")
      field.firstElementChild.contentEditable = false
      container.dataset.originalFieldHtml = ""

      let value =
        field
          .firstElementChild
          .innerHTML
          .trim()

      if (container.dataset.allowBrTags === "true") {
        value = value.replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');
      }
      else {
        value = value.replace(/<br\s*\/?>/gi, ' ');
      }

      value = value.trim()

      field.firstElementChild.innerHTML = value;

      App.Ajax
        .request({
          url: container.dataset.updateUrl,
          method: "PATCH",
          data: {
            kind: container.dataset.kind,
            attribute: container.dataset.attribute,
            [container.dataset.fieldName]: value
          }
        })
    }
  },

  async updateTitleImage(e) {
    const fileInput = e.currentTarget;
    const file = fileInput.files[0];
    const imageUploaderContainer = fileInput.closest(".js-projekt-image-uploader")

    if (file) {
      const imagePreview = imageUploaderContainer.querySelector(".js-projekt-image-upload-preview")
      const previewUrl = URL.createObjectURL(file)

      imagePreview.src = previewUrl
      imagePreview.classList.add("-image-set")

      let formData = new FormData();
      formData.append("kind", imageUploaderContainer.dataset.kind);
      formData.append("attribute", imageUploaderContainer.dataset.attribute);
      formData.append(imageUploaderContainer.dataset.fieldName, file);

      App.Ajax
        .request({
          url: imageUploaderContainer.dataset.updateUrl,
          method: "PATCH",
          processData: false,
          contentType: false,
          data: formData
        })
        .then(() => {
          let mainImage = imageUploaderContainer.querySelector(".resource-image--main");
          let blurImage = imageUploaderContainer.querySelector(".resource-image--blur");

          if (!mainImage || !blurImage) {
            const resourceImage = imageUploaderContainer.querySelector(".resource-image");
            if (resourceImage) {
              resourceImage.innerHTML =
                `<img class="resource-image--main" alt="">` +
                `<img class="resource-image--blur" aria-hidden="true">`;
              mainImage = resourceImage.querySelector(".resource-image--main");
              blurImage = resourceImage.querySelector(".resource-image--blur");
            }
          }

          if (mainImage && blurImage) {
            mainImage.addEventListener("load", () => {
              imagePreview.classList.remove("-image-set");
              imagePreview.src = "";
            }, { once: true });

            mainImage.style.width = "100%";
            mainImage.style.height = "100%";
            mainImage.style.objectFit = "cover";

            mainImage.src = previewUrl;
            blurImage.src = previewUrl;
          }

          const glightbox = imageUploaderContainer.querySelector("a.glightbox");
          if (glightbox) glightbox.setAttribute("href", previewUrl);

          const deleteButton = imageUploaderContainer.querySelector(".js-projekt-banner--image-delete-button");
          if (deleteButton) deleteButton.classList.remove("d-none");

          if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
        })
    }
  },

  async deleteTitleImage(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const container = button.closest(".js-projekt-image-uploader");
    if (!container) return;

    const confirmMessage = container.dataset.deleteConfirm;
    if (confirmMessage && !window.confirm(confirmMessage)) return;

    const formData = new FormData();
    formData.append("kind", container.dataset.kind);
    formData.append("attribute", container.dataset.attribute);
    formData.append("remove_attachment", "1");

    await App.Ajax.request({
      url: container.dataset.updateUrl,
      method: "PATCH",
      processData: false,
      contentType: false,
      data: formData
    });

    const resourceImage = container.querySelector(".resource-image");
    if (resourceImage) {
      const iconClass = container.dataset.placeholderIconClass || "fa-image";
      const ariaLabel = container.dataset.placeholderAriaLabel || "";
      resourceImage.innerHTML =
        `<div class="resource-image--missing-image-placeholder" role="img" aria-label="${ariaLabel}">` +
          `<i class="resource-image--missing-image-placeholder-icon fa ${iconClass}" aria-hidden="true"></i>` +
        `</div>`;
    }

    const glightbox = container.querySelector("a.glightbox");
    if (glightbox) glightbox.removeAttribute("href");

    button.classList.add("d-none");

    if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
  }
};

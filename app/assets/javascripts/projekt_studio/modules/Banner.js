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

    field.firstElementChild.contentEditable = true
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

      const projektId = ProjektStudio.getCurrentProjektId();
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

      $.ajax({
        url: `/admin/projekts/${projektId}/update_page`,
        type: "PATCH",
        dataType: "json",
        headers: {
          'X-Embedded-Frame': ProjektStudio.isEmbedded
        },
        data: {
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

      imagePreview.src = URL.createObjectURL(file)
      imagePreview.classList.add("-image-set")

      const projektId = ProjektStudio.getCurrentProjektId();
      let formData = new FormData();
      formData.append(imageUploaderContainer.dataset.fieldName, file);

      $.ajax({
        url: `/admin/projekts/${projektId}/update_title_image`,
        type: "PATCH",
        processData: false,
        contentType: false,
        headers: {
          'X-Embedded-Frame': ProjektStudio.isEmbedded
        },
        data: formData
      })
    }
  }
};

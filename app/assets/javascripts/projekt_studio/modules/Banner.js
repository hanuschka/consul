// import { resetFoundationAccordionStateFor } from "consul/utils/foundationUtils";
// import { htmlToDomElement, focusContentEditableElement } from "utils/htmlUtils";
// import { sendMessageToDtParentFrame } from "consul/utils/iframeUtils";

ProjektStudio.modules.Banner = {
  initialized: false,
  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    $(document).on("click", ".js-projekt-banner-text-edit-button", this.turnOnTextEdit.bind(this));
    $(document).on("click", ".js-projekt-banner--text-edit-cancel", this.cancelTextEdit.bind(this));
    $(document).on("click", ".js-projekt-banner--text-edit-save", this.saveEditedText.bind(this));
    $(document).on("change", ".js-projekt-banner--image-upload-input", this.updateTitleImage.bind(this));
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
    const {
      container, field
    } = this.getFieldElementsForButton(e.currentTarget)

    if (container.classList.contains("-text-edit-mode")) {
      container.classList.remove("-text-edit-mode")
      field.firstElementChild.contentEditable = false
      container.dataset.originalFieldHtml = ""

      const value = field.firstElementChild.innerHTML.trim()

      if (ProjektStudio.isEmbedded) {
        ProjektStudio.utils.sendMessageToDtParentFrame("updateProjektPage", {
          [container.dataset.fieldName]: value
        })
      } else {
        $.ajax({
          url: `/admin/projekts/${settingId}/settings/${projektId}`,
          type: "PATCH",
          dataType: "json",
          data: {
            "projekt_setting[value]": settingValue
          }
        })
      }
    }
  },

  handleShortcutSaveContentBlock(e) {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      this.saveContentBlockEditedText(e);
    }
  },

  saveContentBlockWithNewContent(contentBlock, contentBlockId, newContent) {
    const newContentBlock = htmlToDomElement(newContent);

    resetFoundationAccordionStateFor(newContentBlock)

    sendMessageToDtParentFrame("updateContentBlock", {
      content_block_id: contentBlockId,
      html: newContentBlock.innerHTML
    })

    // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
    contentBlock.innerHTML = newContentBlock.innerHTML;
    $(contentBlock).foundation();
  },

  async updateTitleImage(e) {
    const fileInput = e.currentTarget;
    const file = fileInput.files[0];
    const imageUploaderContainer = fileInput.closest(".js-projekt-image-uploader")

    if (file) {
      const imagePreview = imageUploaderContainer.querySelector(".js-projekt-image-upload-preview")
      imagePreview.src = URL.createObjectURL(file)
      imagePreview.classList.add("-image-set")

      const title_image_searialized = await serializeFileToBase64(file);

      sendMessageToDtParentFrame("Dt.ProjektStudio.updateTitleImage", {
        title_image_searialized,
        original_image_name: file.name
      })
    }
  }
};

function serializeFileToBase64(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => resolve(reader.result); // `reader.result` contains the Base64 string
    reader.onerror = (error) => reject(error);

    reader.readAsDataURL(file); // Reads the file as a Base64-encoded string
  });
}

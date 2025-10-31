import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ['hiddenInput', 'dropzone', 'fileInput', 'previewContainer', 'imageErrors', 'resetButton', 'formSubmit']

  upload() {
    const file = event.target.files[0];
    if (!file) return

    const upload = new DirectUpload(file, event.target.dataset.directUploadUrl);

    upload.create((error, blob) => {
      if (error) {
        this.imageErrorsTarget.innerHTML = "<span class=''>" + error + "</span>";
        this.fileInputTarget.value = '';
        this.hiddenInputTarget.value = '';
      } else {
        this.showPreview(file)
        this.hiddenInputTarget.value = blob.signed_id;
        this.imageErrorsTarget.innerHTML = '';
        this.resetButtonTarget.classList.remove('d-none');
        this.formSubmitTarget.disabled = false;
        this.formSubmitTarget.focus();
      }
    })
  }

  showPreview(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      this.previewContainerTarget.innerHTML = `
        <img style="width:100%;" src="${e.target.result}" />
      `
    }

    reader.readAsDataURL(file);

    this.dropzoneTarget.classList.add('d-none');
    this.previewContainerTarget.classList.remove('d-none');
  }

  resetForm() {
    this.hiddenInputTarget.value = '';
    this.dropzoneTarget.classList.remove('d-none');
    this.previewContainerTarget.classList.add('d-none');
    this.previewContainerTarget.innerHTML = '';
    this.fileInputTarget.value = '';
    this.hiddenInputTarget.value = '';
    this.resetButtonTarget.classList.add('d-none');
    this.fileInputTarget.focus();
  }
}

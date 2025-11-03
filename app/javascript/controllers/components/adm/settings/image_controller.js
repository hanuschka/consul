import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ['form', 'dropzone', 'preview', 'resetButton', 'fileInput']

  submitForm() {
    this.formTarget.requestSubmit();
  }

  resetForm() {
    this.dropzoneTarget.classList.remove('d-none');
    this.previewTarget.classList.add('d-none');
    this.resetButtonTarget.classList.add('d-none');
    this.fileInputTarget.focus();
  }
}

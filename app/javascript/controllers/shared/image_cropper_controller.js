import { Controller } from "@hotwired/stimulus"
import Cropper from "cropperjs"

// Shared crop step for a file <input> in the /adm pack — the Stimulus
// counterpart of the main app's App.ImageCropper. Expected markup:
//
//   <input type="file"
//     data-controller="shared--image-cropper"
//     data-shared--image-cropper-aspect-ratio-value="1"
//     data-shared--image-cropper-target="input"
//     data-action="change->shared--image-cropper#cropOnSelect">
//   <dialog data-shared--image-cropper-target="dialog">
//     <img data-shared--image-cropper-target="image">
//     <button data-action="shared--image-cropper#confirm">…</button>
//     <button data-action="shared--image-cropper#cancel">…</button>
//   </dialog>
//
// On confirm the cropped File replaces the input's files and a "cropped" event
// is dispatched; on cancel the input is cleared. The vendor Cropper.js CSS and
// the shared .image-cropper styles are loaded via application.adm.scss.
export default class extends Controller {
  static targets = ["input", "dialog", "image"]
  static values = { aspectRatio: Number }

  cropOnSelect() {
    const file = this.inputTarget.files[0]

    if (!file) return
    if (!this.isCroppable(file)) return

    this.fileName = file.name
    this.fileType = file.type
    this.objectUrl = URL.createObjectURL(file)
    this.imageTarget.src = this.objectUrl

    this.dialogTarget.showModal()
    this.initCropper()
  }

  initCropper() {
    this.destroyCropper()
    this.cropper = new Cropper(this.imageTarget, {
      aspectRatio: this.hasAspectRatioValue ? this.aspectRatioValue : NaN,
      viewMode: 1,
      autoCropArea: 1,
      background: false,
      responsive: true
    })
  }

  confirm() {
    if (!this.cropper) return

    this.cropper.getCroppedCanvas(this.canvasOptions()).toBlob(
      (blob) => this.applyBlob(blob),
      this.outputType(),
      0.92
    )
  }

  applyBlob(blob) {
    const file = new File([blob], this.fileName, { type: this.outputType() })
    const dataTransfer = new DataTransfer()

    dataTransfer.items.add(file)
    this.inputTarget.files = dataTransfer.files

    this.teardown()
    this.dispatch("cropped", { detail: { file } })
  }

  cancel() {
    this.inputTarget.value = ""
    this.teardown()
  }

  teardown() {
    this.destroyCropper()
    this.revokeObjectUrl()
    this.dialogTarget.close()
  }

  disconnect() {
    this.destroyCropper()
    this.revokeObjectUrl()
  }

  destroyCropper() {
    if (!this.cropper) return

    this.cropper.destroy()
    this.cropper = null
  }

  revokeObjectUrl() {
    if (!this.objectUrl) return

    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }

  isCroppable(file) {
    return /^image\/(jpeg|png|webp)$/.test(file.type)
  }

  canvasOptions() {
    return { maxWidth: 2400, maxHeight: 2400, imageSmoothingQuality: "high" }
  }

  outputType() {
    return this.fileType === "image/jpeg" ? "image/jpeg" : "image/png"
  }
}

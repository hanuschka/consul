import { Controller } from "@hotwired/stimulus"
import "cropperjs"

const OUTPUT_MAX_DIMENSION = 2400
const JPEG_QUALITY = 0.92

// Shared crop step for a file <input> in the /adm pack — the Stimulus
// counterpart of the main app's App.ImageCropper. Expected markup:
//
//   <input type="file"
//     data-controller="shared--image-cropper"
//     data-shared--image-cropper-aspect-ratio-value="1"
//     data-shared--image-cropper-target="input"
//     data-action="change->shared--image-cropper#cropOnSelect">
//   <dialog data-shared--image-cropper-target="dialog">
//     <%= render Shared::CropperCanvasComponent.new %>
//     <button data-action="shared--image-cropper#confirm">…</button>
//     <button data-action="shared--image-cropper#cancel">…</button>
//   </dialog>
//
// The <cropper-*> custom elements are registered by importing cropperjs; they
// carry their own shadow-DOM styling, so only the surrounding .image-cropper
// chrome comes from application.adm.scss.
//
// On confirm the cropped File replaces the input's files and a "cropped" event
// is dispatched; on cancel the input is cleared.
export default class extends Controller {
  static targets = ["input", "dialog"]
  static values = { aspectRatio: Number }

  connect() {
    this.boundSelectionChange = (event) => this.restrictSelectionToImage(event)
    this.boundImageTransform = () => this.shrinkSelectionAfterTransform()
  }

  cropOnSelect() {
    const file = this.inputTarget.files[0]

    if (!file) return
    if (!this.isCroppable(file)) return

    this.fileName = file.name
    this.fileType = file.type
    this.objectUrl = URL.createObjectURL(file)

    this.dialogTarget.showModal()
    this.startCropper()
  }

  // The <cropper-*> elements measure themselves against their container, so
  // the source is only assigned after the dialog is visible — otherwise the
  // image is laid out inside a zero-sized canvas.
  startCropper() {
    this.selection.aspectRatio = this.hasAspectRatioValue ? this.aspectRatioValue : NaN
    this.image.src = this.objectUrl

    this.image
      .$ready()
      .then((source) => this.fitImageAndSelection(source))
      .catch(() => this.cancel())
  }

  fitImageAndSelection(source) {
    this.matchCanvasToImage(source)
    this.image.$center("contain")
    this.selectWholeImage()

    this.selection.addEventListener("change", this.boundSelectionChange)
    this.image.addEventListener("transform", this.boundImageTransform)
  }

  // Without this the canvas keeps its declared ratio and `contain` letterboxes
  // the image, which the shade then paints as grey bars along two edges.
  matchCanvasToImage(source) {
    this.canvas.style.setProperty(
      "--image-cropper-canvas-ratio",
      source.naturalWidth / source.naturalHeight
    )
  }

  // Replaces v1's `viewMode: 1`: v2 lets the selection roam the whole canvas,
  // so a crop dragged past the image would bake transparent padding into the
  // output file. A 1px tolerance absorbs the rounding $change applies.
  restrictSelectionToImage(event) {
    const bounds = this.imageBounds()

    if (!bounds) return

    const { x, y, width, height } = event.detail

    if (x < bounds.left - 1 ||
        y < bounds.top - 1 ||
        x + width > bounds.left + bounds.width + 1 ||
        y + height > bounds.top + bounds.height + 1) {
      event.preventDefault()
    }
  }

  // Panning or zooming moves the image out from under the selection, which the
  // guard above cannot see. Re-fit once the new transform has been applied.
  shrinkSelectionAfterTransform() {
    window.requestAnimationFrame(() => {
      const bounds = this.imageBounds()

      if (!bounds) return

      const { width, height } = this.fitToAspectRatio(
        Math.min(this.selection.width, bounds.width),
        Math.min(this.selection.height, bounds.height)
      )
      const x = this.clamp(this.selection.x, bounds.left, bounds.left + bounds.width - width)
      const y = this.clamp(this.selection.y, bounds.top, bounds.top + bounds.height - height)

      this.selection.$change(x, y, width, height)
    })
  }

  selectWholeImage() {
    const bounds = this.imageBounds()

    if (!bounds) return

    const { width, height } = this.fitToAspectRatio(bounds.width, bounds.height)
    const x = bounds.left + ((bounds.width - width) / 2)
    const y = bounds.top + ((bounds.height - height) / 2)

    this.selection.$change(x, y, width, height)
  }

  fitToAspectRatio(width, height) {
    const aspectRatio = this.selection.aspectRatio

    if (!aspectRatio || !isFinite(aspectRatio)) return { width, height }
    if (height * aspectRatio > width) return { width, height: width / aspectRatio }

    return { width: height * aspectRatio, height }
  }

  // The image rect in canvas coordinates — the coordinate space the
  // selection's x/y/width/height live in.
  imageBounds() {
    const canvasRect = this.canvas.getBoundingClientRect()
    const imageRect = this.image.getBoundingClientRect()

    if (!imageRect.width || !imageRect.height) return null

    return {
      left: imageRect.left - canvasRect.left,
      top: imageRect.top - canvasRect.top,
      width: imageRect.width,
      height: imageRect.height
    }
  }

  confirm() {
    if (!this.selection.width || !this.selection.height) return

    this.selection
      .$toCanvas(this.canvasOptions())
      .then((canvas) => canvas.toBlob((blob) => this.applyBlob(blob), this.outputType(), JPEG_QUALITY))
      .catch(() => this.cancel())
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
    if (!this.hasDialogTarget) return

    this.selection.removeEventListener("change", this.boundSelectionChange)
    this.image.removeEventListener("transform", this.boundImageTransform)
    this.selection.$clear()
    this.image.removeAttribute("src")
    this.canvas.style.removeProperty("--image-cropper-canvas-ratio")
  }

  revokeObjectUrl() {
    if (!this.objectUrl) return

    URL.revokeObjectURL(this.objectUrl)
    this.objectUrl = null
  }

  isCroppable(file) {
    return /^image\/(jpeg|png|webp)$/.test(file.type)
  }

  clamp(value, min, max) {
    return Math.min(Math.max(value, min), Math.max(min, max))
  }

  // $toCanvas sizes the output from the selection's on-screen size, so the
  // displayed scale has to be divided out to get back to source pixels. Only
  // the cap is passed on, since $toCanvas has no max-size mode and would
  // otherwise upscale a small crop.
  canvasOptions() {
    const [a, b] = this.image.$getTransform()
    const scale = Math.sqrt((a * a) + (b * b)) || 1
    const sourceWidth = this.selection.width / scale
    const sourceHeight = this.selection.height / scale
    const cap = Math.min(1, OUTPUT_MAX_DIMENSION / Math.max(sourceWidth, sourceHeight))

    return {
      width: sourceWidth * cap,
      beforeDraw: (context) => { context.imageSmoothingQuality = "high" }
    }
  }

  outputType() {
    return this.fileType === "image/jpeg" ? "image/jpeg" : "image/png"
  }

  get canvas() {
    return this.dialogTarget.querySelector("cropper-canvas")
  }

  get image() {
    return this.dialogTarget.querySelector("cropper-image")
  }

  get selection() {
    return this.dialogTarget.querySelector("cropper-selection")
  }
}

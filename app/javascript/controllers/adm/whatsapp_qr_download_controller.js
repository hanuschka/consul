import { Controller } from "@hotwired/stimulus"

// Rasterises the inline QR <svg> to a JPEG at print resolution. JPEG has no
// transparency, so the canvas is filled white first — otherwise the code comes
// out on black and stops scanning.
const EXPORT_SIZE = 1024
const JPEG_QUALITY = 0.95

export default class extends Controller {
  static targets = ["code"]

  static values = {
    basename: String
  }

  downloadJpeg() {
    const svg = this.codeTarget.querySelector("svg")
    const source = new XMLSerializer().serializeToString(svg)
    const svgUrl = URL.createObjectURL(new Blob([source], { type: "image/svg+xml;charset=utf-8" }))
    const image = new Image()

    image.addEventListener("load", () => {
      this.exportImage(image)
      URL.revokeObjectURL(svgUrl)
    })

    image.src = svgUrl
  }

  exportImage(image) {
    const canvas = document.createElement("canvas")
    canvas.width = EXPORT_SIZE
    canvas.height = EXPORT_SIZE

    const context = canvas.getContext("2d")
    context.fillStyle = "#ffffff"
    context.fillRect(0, 0, EXPORT_SIZE, EXPORT_SIZE)
    context.drawImage(image, 0, 0, EXPORT_SIZE, EXPORT_SIZE)

    canvas.toBlob((blob) => this.triggerDownload(blob), "image/jpeg", JPEG_QUALITY)
  }

  triggerDownload(blob) {
    const url = URL.createObjectURL(blob)
    const link = document.createElement("a")
    link.href = url
    link.download = `${this.basenameValue}.jpg`

    document.body.append(link)
    link.click()
    link.remove()

    URL.revokeObjectURL(url)
  }
}

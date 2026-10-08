import { Controller } from "@hotwired/stimulus"
import { W, H, Gfx, Firmware, loadFonts, prepareQuestion } from "../../lib/mitmachbox/box_engine"

const INK = [22, 22, 22]
const PAPER = [232, 231, 225]
const FULL_REFRESH_FRAME_MS = 150
const PARTIAL_REFRESH_FLASH_MS = 110

let lastShown = null
let edgeCurve = null

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms))
const reducedMotion = () => window.matchMedia?.("(prefers-reduced-motion: reduce)").matches

export default class extends Controller {
  static targets = ["screen", "input", "key"]

  static values = {
    fontsUrl: String,
    screen: String,
    question: Object,
    step: Number,
    total: Number,
    missing: Boolean
  }

  connect() {
    this.firmware = new Firmware()
    this.sequence = 0
    this.queue = Promise.resolve()
    this.selection = this.currentSelection()
    this.requiredHint = this.missingValue
    this.offscreen = document.createElement("canvas")
    this.offscreen.width = W
    this.offscreen.height = H
    this.offscreenContext = this.offscreen.getContext("2d")
    this.image = this.offscreenContext.createImageData(W, H)
    this.resizeObserver = new ResizeObserver(() => this.blit())
    this.resizeObserver.observe(this.screenTarget)
    this.updateKeys()

    loadFonts(this.fontsUrlValue).then(() => {
      if (this.element.isConnected) this.showFull()
    })
  }

  disconnect() {
    this.sequence++
    this.resizeObserver?.disconnect()
  }

  select() {
    const next = this.currentSelection()
    const changed = next.map((on, i) => on !== this.selection[i])
    const order = changed.map((_, i) => i).sort((a, b) => Number(next[a]) - Number(next[b]))
    this.selection = next
    this.updateKeys()
    if (!this.shown) return

    order.filter((i) => changed[i]).forEach((i) => {
      this.showPartial(this.firmware.cardWindow(i, this.cardsTop), (g) => {
        this.firmware.drawCard(g, this.question, i, next[i], this.cardsTop)
      })
    })
    if (this.requiredHint && next.some(Boolean)) {
      this.requiredHint = false
      this.showPartial(this.firmware.metaRightWindow(this.cardsTop), (g) => {
        this.firmware.drawMetaRight(g, this.stepValue, this.totalValue, false, this.cardsTop)
      })
    }
  }

  focus() {
    this.inputTargets.forEach((input, i) => {
      const focused = input === document.activeElement && input.matches(":focus-visible")
      this.keyTargets[i]?.classList.toggle("is-focused", focused)
    })
  }

  get question() {
    this.preparedQuestion ||= prepareQuestion(this.questionValue)
    return this.preparedQuestion
  }

  currentSelection() {
    const selection = [false, false, false, false, false]
    this.inputTargets.forEach((input, i) => { selection[i] = input.checked })
    return selection
  }

  updateKeys() {
    this.keyTargets.forEach((key, i) => key.classList.toggle("is-down", !!this.selection[i]))
  }

  render() {
    const g = new Gfx()
    if (this.screenValue === "welcome") {
      this.firmware.drawWelcome(g)
    } else if (this.screenValue === "thanks") {
      this.firmware.drawThanks(g)
    } else {
      this.cardsTop = this.firmware.drawQuestion(g, this.question, this.stepValue, this.totalValue, this.selection)
      if (this.requiredHint) {
        g.setPartialWindow(this.firmware.metaRightWindow(this.cardsTop))
        g.firstPage()
        this.firmware.drawMetaRight(g, this.stepValue, this.totalValue, true, this.cardsTop)
        g.setFullWindow()
      }
    }
    return g.fb
  }

  showFull() {
    const previous = lastShown
    const next = this.render()
    if (previous) this.show(previous, next, null)
    else {
      this.shown = next
      lastShown = next
      this.paint(next)
    }
  }

  showPartial(rect, draw) {
    const g = new Gfx()
    const win = g.setPartialWindow(rect)
    g.firstPage()
    draw(g)
    const next = this.shown.slice()
    for (let y = win.y; y < win.y + win.h; y++) {
      next.set(g.fb.subarray(y * W + win.x, y * W + win.x + win.w), y * W + win.x)
    }
    this.show(this.shown, next, win)
  }

  show(previous, next, win) {
    this.shown = next
    lastShown = next
    const current = ++this.sequence

    if (reducedMotion()) {
      this.paint(next)
      return
    }

    this.queue = this.queue.then(async () => {
      const live = () => current === this.sequence
      if (!live()) return

      if (win) {
        const flash = previous.slice()
        for (let y = win.y; y < win.y + win.h; y++) {
          for (let x = win.x; x < win.x + win.w; x++) flash[y * W + x] = next[y * W + x] ? 0 : 1
        }
        this.paint(flash)
        await sleep(PARTIAL_REFRESH_FLASH_MS)
      } else {
        const frames = [previous.map((p) => (p ? 0 : 1)), new Uint8Array(W * H).fill(1), new Uint8Array(W * H)]
        for (const frame of frames) {
          if (!live()) return
          this.paint(frame)
          await sleep(FULL_REFRESH_FRAME_MS)
        }
      }

      if (!live()) return
      this.paint(this.shown)
    })
  }

  paint(fb) {
    const data = this.image.data
    for (let k = 0, p = 0; k < W * H; k++, p += 4) {
      const color = fb[k] ? INK : PAPER
      data[p] = color[0]
      data[p + 1] = color[1]
      data[p + 2] = color[2]
      data[p + 3] = 255
    }
    this.offscreenContext.putImageData(this.image, 0, 0)
    this.painted = true
    this.blit()
  }

  blit() {
    if (!this.painted) return

    const canvas = this.screenTarget
    const rect = canvas.getBoundingClientRect()
    const ratio = window.devicePixelRatio || 1
    const w = Math.max(1, Math.round(rect.width * ratio))
    const h = Math.max(1, Math.round(rect.height * ratio))
    if (canvas.width !== w || canvas.height !== h) {
      canvas.width = w
      canvas.height = h
    }

    const context = canvas.getContext("2d")
    const scale = w / W
    const exact = scale >= 1 && Math.abs(scale - Math.round(scale)) < 0.005
    context.imageSmoothingEnabled = !exact
    context.imageSmoothingQuality = "high"
    context.drawImage(this.offscreen, 0, 0, w, h)
    if (exact) return

    if (!edgeCurve) {
      edgeCurve = new Uint8ClampedArray(256)
      for (let v = 0; v < 256; v++) {
        const t = (v - 22) / 210
        edgeCurve[v] = Math.round(Math.min(1, Math.max(0, (t - 0.5) * 2.4 + 0.5)) * 255)
      }
    }
    const image = context.getImageData(0, 0, w, h)
    const pixels = image.data
    for (let k = 0; k < pixels.length; k += 4) {
      const t = edgeCurve[pixels[k]] / 255
      pixels[k] = 22 + t * 210
      pixels[k + 1] = 22 + t * 209
      pixels[k + 2] = 22 + t * 203
    }
    context.putImageData(image, 0, 0)
  }
}

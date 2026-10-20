export const W = 800
export const H = 480

const BLACK = 1
const WHITE = 0

const HIDDEN = 10
const MARGIN_X = 40
const MARGIN_TOP = 44
const MARGIN_R = 30
const KEY6_Y = 215
const CARD_X0 = 4
const CARD_W = 152
const CARD_GAP = 8
const CARD_R = 12
const CARD_LH = 21
const CARDS_TOP_MIN = 160
const CARDS_TOP_MAX = 232
const META_H = 34
const META_ACTION_W = 300
const NUM_BASE_CARD = 466
const NUM_BASE_HOME = 447
const START_X = 624
const START_H = 72
const MAX_LINES = 10
const MAX_PIECES = 32
const MAX_OPTIONS = 5

const FONT_PROMPT = "helvB24"
const FONT_PROMPT2 = "helvB18"
const FONT_PROMPT3 = "helvB14"
const FONT_TEXT = "helvR18"
const FONT_CARD = "helvR14"
const FONT_META = "helvR14"
const FONT_NUMBER = "helvB18"

const TXT_WELCOME = "Herzlich willkommen!"
const TXT_WELCOME_SUB = "Ihre Meinung ist gefragt."
const TXT_STEP_NEXT = "Weiter zur nächsten Frage"
const TXT_STEP_NEXT_SUB = "mit der Taste rechts neben dem Bildschirm"
const TXT_STEP_PICK = "Antwort wählen"
const TXT_STEP_PICK_SUB = "mit der Taste direkt unter der Antwort"
const TXT_START = "Start"
const TXT_MULTI = "Mehrere Antworten möglich"
const TXT_NEXT = "Nächste Frage"
const TXT_LAST = "Abschließen"
const TXT_REQUIRED = "Bitte Antwort wählen"
const TXT_THANKS = "Vielen Dank für Ihre Teilnahme!"
const TXT_THANKS_SUB = "Ihre Antworten sind gespeichert."

const SOFT_HYPHEN = "­"

const CHAR_REPLACEMENTS = [
  ["–", "-"], ["—", "-"], ["‒", "-"], ["−", "-"], ["‐", "-"], ["‑", "-"],
  ["‘", "'"], ["’", "'"], ["‚", "'"], ["‹", "'"], ["›", "'"],
  ["“", "\""], ["”", "\""], ["„", "\""],
  ["…", "..."], ["€", "EUR"], ["•", "·"],
  [" ", " "], [" ", " "], ["​", ""]
]

let fontData = null
let fontsRequest = null
const fontCache = {}

export function loadFonts(url) {
  if (fontData) return Promise.resolve()

  fontsRequest ||= fetch(url)
    .then((response) => {
      if (!response.ok) throw new Error(`Mitmachbox fonts: HTTP ${response.status}`)
      return response.json()
    })
    .then((data) => { fontData = data })
    .catch((error) => {
      fontsRequest = null
      throw error
    })

  return fontsRequest
}

const idiv = (a, b) => Math.trunc(a / b)
const lround = (value) => Math.sign(value) * Math.round(Math.abs(value))
const f32 = Math.fround

function base64Bytes(string) {
  const binary = atob(string)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes
}

function getFont(name) {
  if (fontCache[name]) return fontCache[name]

  const d = base64Bytes(fontData[`${name}_tf`])
  const s8 = (v) => (v > 127 ? v - 256 : v)
  const font = {
    d,
    bp0: d[2], bp1: d[3], bw: d[4], bh: d[5], bx: d[6], by: d[7], bd: d[8],
    ascent: s8(d[13]),
    descent: s8(d[14]),
    ascentPara: s8(d[15]),
    descentPara: s8(d[16]),
    upperA: (d[17] << 8) | d[18],
    lowerA: (d[19] << 8) | d[20],
    glyphs: new Map()
  }
  fontCache[name] = font
  return font
}

function findGlyph(font, encoding) {
  if (font.glyphs.has(encoding)) return font.glyphs.get(encoding)

  let glyph = null
  if (encoding <= 255) {
    const d = font.d
    let p = 23 + (encoding >= 97 ? font.lowerA : encoding >= 65 ? font.upperA : 0)
    for (;;) {
      if (d[p + 1] === 0 || d[p + 1] === undefined) break
      if (d[p] === encoding) { glyph = decodeGlyph(font, p + 2); break }
      p += d[p + 1]
    }
  }
  font.glyphs.set(encoding, glyph)
  return glyph
}

function decodeGlyph(font, start) {
  const d = font.d
  let ptr = start
  let bit = 0
  const unsigned = (count) => {
    let value = (d[ptr] || 0) >> bit
    let next = bit + count
    if (next >= 8) {
      ptr++
      value |= (d[ptr] || 0) << (8 - bit)
      next -= 8
    }
    bit = next
    return value & ((1 << count) - 1)
  }
  const signed = (count) => unsigned(count) - (1 << (count - 1))
  const w = unsigned(font.bw)
  const h = unsigned(font.bh)
  const x = signed(font.bx)
  const y = signed(font.by)
  const dx = signed(font.bd)
  const runs = []

  if (w > 0) {
    let lx = 0
    let ly = 0
    const run = (length, foreground) => {
      let count = length
      for (;;) {
        const remaining = w - lx
        const current = count < remaining ? count : remaining
        if (current > 0) runs.push(lx, ly, current, foreground ? 1 : 0)
        if (count < remaining) break
        count -= remaining
        lx = 0
        ly++
      }
      lx += count
    }
    for (;;) {
      const a = unsigned(font.bp0)
      const b = unsigned(font.bp1)
      do { run(a, false); run(b, true) } while (unsigned(1) !== 0)
      if (ly >= h) break
    }
  }

  return { w, h, x, y, dx, runs }
}

function alignWindow(rect) {
  const x = Math.min(rect.x, W)
  const y = Math.min(rect.y, H)
  let w = Math.min(rect.w, W - x)
  const h = Math.min(rect.h, H - y)
  w += x % 8
  if (w % 8 > 0) w += 8 - (w % 8)
  return { x: x - (x % 8), y, w, h }
}

export class Gfx {
  constructor() {
    this.fb = new Uint8Array(W * H)
    this.window = { x: 0, y: 0, w: W, h: H }
    this.font = null
    this.fg = BLACK
    this.bg = WHITE
  }

  setFullWindow() {
    this.window = { x: 0, y: 0, w: W, h: H }
  }

  setPartialWindow(rect) {
    this.window = alignWindow(rect)
    return this.window
  }

  firstPage() {
    this.fillScreen(WHITE)
  }

  pixel(x, y, color) {
    const win = this.window
    if (x < win.x || x >= win.x + win.w || y < win.y || y >= win.y + win.h) return
    this.fb[y * W + x] = color
  }

  line(x0, y0, x1, y1, color) {
    const steep = Math.abs(y1 - y0) > Math.abs(x1 - x0)
    if (steep) {
      [x0, y0] = [y0, x0];
      [x1, y1] = [y1, x1]
    }
    if (x0 > x1) {
      [x0, x1] = [x1, x0];
      [y0, y1] = [y1, y0]
    }
    const dx = x1 - x0
    const dy = Math.abs(y1 - y0)
    let err = idiv(dx, 2)
    const step = y0 < y1 ? 1 : -1
    for (; x0 <= x1; x0++) {
      if (steep) this.pixel(y0, x0, color)
      else this.pixel(x0, y0, color)
      err -= dy
      if (err < 0) {
        y0 += step
        err += dx
      }
    }
  }

  hline(x, y, w, color) { this.line(x, y, x + w - 1, y, color) }

  vline(x, y, h, color) { this.line(x, y, x, y + h - 1, color) }

  fillRect(x, y, w, h, color) {
    for (let i = x; i < x + w; i++) this.vline(i, y, h, color)
  }

  fillScreen(color) {
    const win = this.window
    for (let y = win.y; y < win.y + win.h; y++) this.fb.fill(color, y * W + win.x, y * W + win.x + win.w)
  }

  fillCircleHelper(x0, y0, r, corners, delta, color) {
    let f = 1 - r
    let ddFx = 1
    let ddFy = -2 * r
    let x = 0
    let y = r
    let px = x
    let py = y
    delta++
    while (x < y) {
      if (f >= 0) {
        y--
        ddFy += 2
        f += ddFy
      }
      x++
      ddFx += 2
      f += ddFx
      if (x < y + 1) {
        if (corners & 1) this.vline(x0 + x, y0 - y, 2 * y + delta, color)
        if (corners & 2) this.vline(x0 - x, y0 - y, 2 * y + delta, color)
      }
      if (y !== py) {
        if (corners & 1) this.vline(x0 + py, y0 - px, 2 * px + delta, color)
        if (corners & 2) this.vline(x0 - py, y0 - px, 2 * px + delta, color)
        py = y
      }
      px = x
    }
  }

  fillCircle(x0, y0, r, color) {
    this.vline(x0, y0 - r, 2 * r + 1, color)
    this.fillCircleHelper(x0, y0, r, 3, 0, color)
  }

  fillRoundRect(x, y, w, h, r, color) {
    const maxRadius = idiv(w < h ? w : h, 2)
    if (r > maxRadius) r = maxRadius
    this.fillRect(x + r, y, w - 2 * r, h, color)
    this.fillCircleHelper(x + w - r - 1, y + r, r, 1, h - 2 * r - 1, color)
    this.fillCircleHelper(x + r, y + r, r, 2, h - 2 * r - 1, color)
  }

  fillTriangle(x0, y0, x1, y1, x2, y2, color) {
    if (y0 > y1) { [y0, y1] = [y1, y0]; [x0, x1] = [x1, x0] }
    if (y1 > y2) { [y2, y1] = [y1, y2]; [x2, x1] = [x1, x2] }
    if (y0 > y1) { [y0, y1] = [y1, y0]; [x0, x1] = [x1, x0] }

    let a
    let b
    if (y0 === y2) {
      a = b = x0
      if (x1 < a) a = x1
      else if (x1 > b) b = x1
      if (x2 < a) a = x2
      else if (x2 > b) b = x2
      this.hline(a, y0, b - a + 1, color)
      return
    }

    const dx01 = x1 - x0
    const dy01 = y1 - y0
    const dx02 = x2 - x0
    const dy02 = y2 - y0
    const dx12 = x2 - x1
    const dy12 = y2 - y1
    let sa = 0
    let sb = 0
    const last = y1 === y2 ? y1 : y1 - 1
    let y
    for (y = y0; y <= last; y++) {
      a = x0 + idiv(sa, dy01)
      b = x0 + idiv(sb, dy02)
      sa += dx01
      sb += dx02
      if (a > b) [a, b] = [b, a]
      this.hline(a, y, b - a + 1, color)
    }
    sa = dx12 * (y - y1)
    sb = dx02 * (y - y0)
    for (; y <= y2; y++) {
      a = x1 + idiv(sa, dy12)
      b = x0 + idiv(sb, dy02)
      sa += dx12
      sb += dx02
      if (a > b) [a, b] = [b, a]
      this.hline(a, y, b - a + 1, color)
    }
  }

  thickLine(x0, y0, x1, y1, t, color) {
    let len = f32(Math.sqrt(f32(f32(f32(x1 - x0) * (x1 - x0)) + f32(f32(y1 - y0) * (y1 - y0)))))
    if (len < 1) len = 1
    const nx = lround(f32(f32(f32(-(y1 - y0) / len) * t) / 2))
    const ny = lround(f32(f32(f32((x1 - x0) / len) * t) / 2))
    this.fillTriangle(x0 + nx, y0 + ny, x1 + nx, y1 + ny, x1 - nx, y1 - ny, color)
    this.fillTriangle(x0 + nx, y0 + ny, x1 - nx, y1 - ny, x0 - nx, y0 - ny, color)
    this.fillCircle(x0, y0, idiv(t, 2), color)
    this.fillCircle(x1, y1, idiv(t, 2), color)
  }

  setFont(name) { this.font = getFont(name) }

  setInk(inverted) {
    this.fg = inverted ? WHITE : BLACK
    this.bg = inverted ? BLACK : WHITE
  }

  ascent() { return this.font.ascent }

  descent() { return this.font.descent }

  width(text) {
    let w = 0
    let dx = 0
    let glyphWidth = 0
    let xOffset = 0
    for (const char of text) {
      const glyph = findGlyph(this.font, char.codePointAt(0))
      if (glyph) {
        dx = glyph.dx
        glyphWidth = glyph.w
        xOffset = glyph.x
      } else {
        dx = 0
      }
      w += dx
    }
    if (glyphWidth !== 0) w = w - dx + glyphWidth + xOffset
    return w
  }

  print(x, y, text) {
    for (const char of text) {
      const encoding = char.codePointAt(0)
      if (encoding === 10) {
        x = 0
        y += this.font.ascentPara - this.font.descentPara
        continue
      }
      if (encoding === 13) {
        x = 0
        continue
      }
      const glyph = findGlyph(this.font, encoding)
      if (!glyph) continue
      if (glyph.w > 0) {
        const tx = x + glyph.x
        const ty = y - (glyph.h + glyph.y)
        const runs = glyph.runs
        for (let k = 0; k < runs.length; k += 4) {
          this.hline(tx + runs[k], ty + runs[k + 1], runs[k + 2], runs[k + 3] ? this.fg : this.bg)
        }
      }
      x += glyph.dx
    }
  }

  printCentered(text, cx, baseline) {
    this.print(cx - idiv(this.width(text), 2), baseline, text)
  }
}

const clean = (text) => text.split(SOFT_HYPHEN).join("")
const asciiTrim = (text) => text.replace(/^[ \t\n\v\f\r]+|[ \t\n\v\f\r]+$/g, "")
const asciiLower = (text) => text.replace(/[A-Z]/g, (char) => char.toLowerCase())

function fixChars(text) {
  let result = String(text ?? "")
  for (const [from, to] of CHAR_REPLACEMENTS) result = result.split(from).join(to)
  return result
}

class Pieces {
  constructor(report, word) {
    this.items = []
    this.count = 0
    this.report = report
    this.word = word
  }

  splitByCharacters() {
    this.report?.add(this.word)
  }

  add(text, soft) {
    if (this.count < MAX_PIECES) this.items[this.count] = { text, soft }
    this.count++
  }
}

function hardSplit(g, word, maxW, pieces, lastSoft) {
  pieces.splitByCharacters()
  let chunk = ""
  for (const char of word) {
    if (chunk !== "" && g.width(`${chunk}${char}-`) > maxW) {
      pieces.add(chunk, true)
      chunk = ""
    }
    chunk += char
  }
  if (chunk !== "") pieces.add(chunk, lastSoft)
}

function splitSyllables(g, syllables, maxW, pieces) {
  let syl = syllables
  while (syl.length > 0) {
    const full = syl.join("")
    if (g.width(full) <= maxW) {
      pieces.add(full, false)
      return
    }
    if (syl.length < 2) {
      hardSplit(g, full, maxW, pieces, false)
      return
    }

    let best = -1
    let greedy = -1
    let bestScore = 32767
    let head = ""
    for (let k = 1; k < syl.length; k++) {
      head += syl[k - 1]
      const wp = g.width(`${head}-`)
      if (wp > maxW) break
      greedy = k
      const wr = g.width(syl.slice(k).join(""))
      if (wr <= maxW && Math.max(wp, wr) < bestScore) {
        bestScore = Math.max(wp, wr)
        best = k
      }
    }
    const k = best > 0 ? best : greedy
    if (k < 1) {
      hardSplit(g, full, maxW, pieces, false)
      return
    }

    pieces.add(syl.slice(0, k).join(""), true)
    syl = syl.slice(k)
  }
}

function syllablesOf(part) {
  const syllables = []
  let from = 0
  let at
  while ((at = part.indexOf(SOFT_HYPHEN, from)) >= 0 && syllables.length < MAX_PIECES - 1) {
    syllables.push(part.substring(from, at))
    from = at + 1
  }
  syllables.push(part.substring(from))
  return syllables
}

function breakPieces(g, word, maxW, report) {
  const pieces = new Pieces(report, clean(word))
  const addPart = (part) => {
    const cleaned = clean(part)
    if (g.width(cleaned) <= maxW) pieces.add(cleaned, false)
    else splitSyllables(g, syllablesOf(part), maxW, pieces)
  }
  let part = ""
  for (let i = 0; i < word.length; i++) {
    const char = word[i]
    part += char
    const last = i === word.length - 1
    if ((char === "-" || char === "/") && !last && word[i + 1] !== "/") {
      addPart(part)
      part = ""
    }
  }
  if (part !== "") addPart(part)
  return pieces.items.slice(0, Math.min(pieces.count, MAX_PIECES))
}

function wrapText(g, text, maxW, report) {
  const lines = []
  let count = 0
  let line = ""
  let lastSoft = false
  const emit = (done) => {
    if (count < MAX_LINES) lines[count] = done
    count++
  }

  let start = 0
  while (start <= text.length) {
    let space = text.indexOf(" ", start)
    if (space < 0) space = text.length
    const raw = text.substring(start, space)
    const word = clean(raw)
    const sep = line === "" ? "" : " "
    start = space + 1

    if (g.width(line + sep + word) <= maxW) {
      line += sep + word
      lastSoft = false
      continue
    }
    if (g.width(word) <= maxW) {
      if (line !== "") emit(lastSoft ? `${line}-` : line)
      line = word
      lastSoft = false
      continue
    }
    breakPieces(g, raw, maxW, report).forEach((piece, i) => {
      const candidate = line + (i === 0 ? sep : "") + piece.text
      if (line === "" || g.width(piece.soft ? `${candidate}-` : candidate) <= maxW) {
        line = candidate
      } else {
        emit(lastSoft ? `${line}-` : line)
        line = piece.text
      }
      lastSoft = piece.soft
    })
  }
  if (line !== "") emit(lastSoft ? `${line}-` : line)
  return { lines, count, shown: Math.min(count, MAX_LINES) }
}

function drawLinesLeft(g, x, baseline, lines, n, lineHeight) {
  for (let i = 0; i < n && i < MAX_LINES; i++) g.print(x, baseline + i * lineHeight, lines[i])
}

function drawLinesCentered(g, cx, left, right, baseline, lines, n, lineHeight) {
  let blockW = 0
  for (let i = 0; i < n && i < MAX_LINES; i++) blockW = Math.max(blockW, g.width(lines[i]))
  const wanted = cx - idiv(blockW, 2)
  const high = right - blockW
  const blockX = wanted < left ? left : (wanted > high ? high : wanted)
  for (let i = 0; i < n && i < MAX_LINES; i++) {
    g.print(blockX + idiv(blockW - g.width(lines[i]), 2), baseline + i * lineHeight, lines[i])
  }
}

const cardX = (i) => CARD_X0 + i * (CARD_W + CARD_GAP)
const cardVisL = (i) => Math.max(cardX(i), HIDDEN)
const cardVisR = (i) => Math.min(cardX(i) + CARD_W, W - HIDDEN)
const cardCenter = (i) => idiv(cardVisL(i) + cardVisR(i), 2)
const metaRightX = () => (W - MARGIN_R - META_ACTION_W) & ~7

export function prepareQuestion(question) {
  return {
    prompt: fixChars(question.prompt),
    multiple: !!question.multiple,
    options: (question.options || []).slice(0, MAX_OPTIONS).map((option) => ({ label: fixChars(option.label) }))
  }
}

function promptText(question) {
  let prompt = question.prompt
  if (!question.multiple) return prompt
  prompt = asciiTrim(prompt)
  const open = prompt.lastIndexOf("(")
  if (open >= 0 && prompt.endsWith(")")) {
    const inner = asciiLower(prompt.substring(open + 1))
    if (inner.startsWith("mehrere") || inner.startsWith("mehrfach")) prompt = asciiTrim(prompt.substring(0, open))
  }
  return prompt
}

export class Firmware {
  fitPrompt(g, question) {
    const fonts = [FONT_PROMPT, FONT_PROMPT2, FONT_PROMPT3]
    const heights = [34, 30, 24]
    const width = W - MARGIN_X - MARGIN_R
    const text = promptText(question)
    for (let s = 0; s < 3; s++) {
      g.setFont(fonts[s])
      const wrapped = wrapText(g, text, width)
      const last = MARGIN_TOP + g.ascent() + (wrapped.count - 1) * heights[s] - g.descent()
      const top = Math.max(CARDS_TOP_MIN, last + 10 + META_H)
      if (top <= CARDS_TOP_MAX || s === 2) {
        return {
          font: fonts[s],
          lineHeight: heights[s],
          lines: wrapped.lines,
          count: wrapped.shown,
          cardsTop: Math.min(top, CARDS_TOP_MAX),
          shrunk: s > 0,
          overflow: top > CARDS_TOP_MAX || wrapped.count > MAX_LINES
        }
      }
    }
    return null
  }

  drawCard(g, question, i, on, cardsTop) {
    const x = cardX(i)
    const top = cardsTop
    const h = H + 16 - top
    g.fillRoundRect(x, top, CARD_W, h, CARD_R, BLACK)
    if (!on) g.fillRoundRect(x + 1, top + 1, CARD_W - 2, h - 2, CARD_R - 1, WHITE)
    g.setInk(on)

    const left = cardVisL(i)
    const right = cardVisR(i)
    const cx = cardCenter(i)
    g.setFont(FONT_NUMBER)
    const numberAscent = g.ascent()
    g.printCentered(String(i + 1), cx, NUM_BASE_CARD)

    g.setFont(FONT_CARD)
    const wrapped = wrapText(g, question.options[i].label, right - left - 12)
    const roomTop = top + 6
    const roomBot = NUM_BASE_CARD - numberAscent - 4
    const textTop = roomTop + Math.max(0, idiv(roomBot - roomTop - wrapped.shown * CARD_LH, 2))
    drawLinesCentered(g, cx, left + 6, right - 6, textTop + g.ascent(), wrapped.lines, wrapped.shown, CARD_LH)
  }

  cardWindow(i, cardsTop) {
    return { x: cardX(i), y: cardsTop, w: CARD_W, h: H - cardsTop }
  }

  metaRightWindow(cardsTop) {
    const x = metaRightX()
    return { x, y: cardsTop - META_H, w: W - x, h: META_H - 2 }
  }

  drawMetaLeft(g, question, shown, total, cardsTop) {
    const baseline = cardsTop - 11
    g.setInk(false)
    g.setFont(FONT_META)
    const progress = total > 0 ? `Frage ${shown} von ${total}` : `Frage ${shown}`
    g.print(MARGIN_X, baseline, progress)
    if (question.multiple) {
      const x = MARGIN_X + g.width(progress) + 14
      g.fillRect(x, baseline - 15, 1, 18, BLACK)
      g.print(x + 15, baseline, TXT_MULTI)
    }
  }

  drawMetaRight(g, shown, total, requiredHint, cardsTop) {
    const y = cardsTop - 11
    g.setInk(false)
    g.setFont(FONT_META)
    let text = TXT_REQUIRED
    let arrow = false
    if (!requiredHint) {
      text = total > 0 && shown >= total ? TXT_LAST : TXT_NEXT
      arrow = true
    }
    let x = W - MARGIN_R
    if (arrow) {
      g.fillTriangle(x - 9, y - 13, x - 9, y - 1, x, y - 7, BLACK)
      x -= 16
    }
    g.print(x - g.width(text), y, text)
  }

  drawQuestion(g, question, shown, total, selection) {
    const fit = this.fitPrompt(g, question)
    g.fillScreen(WHITE)
    g.setInk(false)
    g.setFont(fit.font)
    drawLinesLeft(g, MARGIN_X, MARGIN_TOP + g.ascent(), fit.lines, fit.count, fit.lineHeight)
    this.drawMetaLeft(g, question, shown, total, fit.cardsTop)
    this.drawMetaRight(g, shown, total, false, fit.cardsTop)
    question.options.forEach((_, i) => this.drawCard(g, question, i, !!selection[i], fit.cardsTop))
    return fit.cardsTop
  }

  drawWelcomeStep(g, down, headY, head, text) {
    const icon = 34
    const tx = MARGIN_X + icon + 16
    const tw = START_X - 24 - tx
    const top = headY + 6 - idiv(icon, 2)
    g.fillRoundRect(MARGIN_X, top, icon, icon, 7, BLACK)
    const cx = MARGIN_X + idiv(icon, 2)
    const cy = top + idiv(icon, 2)
    if (down) g.fillTriangle(cx - 10, cy - 6, cx + 10, cy - 6, cx, cy + 8, WHITE)
    else g.fillTriangle(cx - 6, cy - 10, cx - 6, cy + 10, cx + 8, cy, WHITE)
    g.setInk(false)
    g.setFont(FONT_NUMBER)
    const heading = wrapText(g, head, tw)
    drawLinesLeft(g, tx, headY, heading.lines, heading.shown, 26)
    g.setFont(FONT_TEXT)
    const body = wrapText(g, text, tw)
    drawLinesLeft(g, tx, headY + heading.shown * 26, body.lines, body.shown, 26)
  }

  drawWelcome(g) {
    g.fillScreen(WHITE)
    g.setInk(false)
    g.setFont(FONT_PROMPT)
    let y = MARGIN_TOP + g.ascent()
    let wrapped = wrapText(g, TXT_WELCOME, W - MARGIN_X - MARGIN_R)
    drawLinesLeft(g, MARGIN_X, y, wrapped.lines, wrapped.shown, 34)
    y += (wrapped.shown - 1) * 34 + 40
    g.setFont(FONT_TEXT)
    wrapped = wrapText(g, TXT_WELCOME_SUB, W - MARGIN_X - MARGIN_R)
    drawLinesLeft(g, MARGIN_X, y, wrapped.lines, wrapped.shown, 24)

    g.setFont(FONT_NUMBER)
    const numbersTop = NUM_BASE_HOME - g.ascent()
    this.drawWelcomeStep(g, false, KEY6_Y - 6, TXT_STEP_NEXT, TXT_STEP_NEXT_SUB)
    this.drawWelcomeStep(g, true, numbersTop - 36 - 26 - 5, TXT_STEP_PICK, TXT_STEP_PICK_SUB)

    const by = KEY6_Y - idiv(START_H, 2)
    g.fillRoundRect(START_X, by, W - START_X + CARD_R, START_H, CARD_R, BLACK)
    g.setInk(true)
    g.setFont(FONT_PROMPT)
    g.print(START_X + 18, by + idiv(START_H + g.ascent(), 2), TXT_START)
    g.fillTriangle(W - 40, by + 22, W - 40, by + START_H - 22, W - 14, KEY6_Y, WHITE)

    g.setInk(false)
    g.setFont(FONT_NUMBER)
    for (let i = 0; i < 5; i++) {
      const cx = cardCenter(i)
      g.printCentered(String(i + 1), cx, NUM_BASE_HOME)
      g.fillTriangle(cx - 11, NUM_BASE_HOME + 8, cx + 11, NUM_BASE_HOME + 8, cx, NUM_BASE_HOME + 24, BLACK)
    }
  }

  drawThanks(g) {
    g.fillScreen(WHITE)
    const cx = idiv(W, 2)
    const cy = 182
    g.fillCircle(cx, cy, 58, BLACK)
    g.thickLine(cx - 27, cy + 2, cx - 8, cy + 22, 11, WHITE)
    g.thickLine(cx - 8, cy + 22, cx + 28, cy - 20, 11, WHITE)
    g.setInk(false)
    g.setFont(FONT_PROMPT)
    g.printCentered(TXT_THANKS, cx, 306)
    g.setFont(FONT_TEXT)
    g.printCentered(TXT_THANKS_SUB, cx, 348)
  }
}

function missingCharacters(g, text) {
  const missing = new Set()
  for (const char of clean(text)) {
    if (char !== " " && !findGlyph(g.font, char.codePointAt(0))) missing.add(char)
  }
  return [...missing]
}

function analyzeCard(g, label, index, cardsTop) {
  g.setFont(FONT_NUMBER)
  const room = NUM_BASE_CARD - g.ascent() - 4 - (cardsTop + 6)
  g.setFont(FONT_CARD)
  const splitWords = new Set()
  const wrapped = wrapText(g, label, cardVisR(index) - cardVisL(index) - 12, splitWords)
  return {
    lines: wrapped.count,
    room: Math.floor(room / CARD_LH),
    overflow: wrapped.count * CARD_LH > room,
    splitWords: [...splitWords],
    missing: missingCharacters(g, label)
  }
}

export function analyzeQuestion(rawQuestion) {
  const question = prepareQuestion(rawQuestion)
  const g = new Gfx()
  const fit = new Firmware().fitPrompt(g, question)
  const splitWords = new Set()
  g.setFont(fit.font)
  wrapText(g, promptText(question), W - MARGIN_X - MARGIN_R, splitWords)
  return {
    overflow: fit.overflow,
    shrunk: fit.shrunk,
    splitWords: [...splitWords],
    missing: missingCharacters(g, question.prompt),
    options: question.options.map((option, index) => analyzeCard(g, option.label, index, fit.cardsTop))
  }
}

export function analyzeOption(rawQuestion, label, index) {
  const question = prepareQuestion({ ...rawQuestion, options: [] })
  const g = new Gfx()
  const fit = new Firmware().fitPrompt(g, question)
  return analyzeCard(g, fixChars(label), Math.min(Math.max(index, 0), MAX_OPTIONS - 1), fit.cardsTop)
}

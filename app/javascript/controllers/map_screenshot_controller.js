import { Controller } from "@hotwired/stimulus"

/**
 * Map Screenshot Controller
 *
 * Takes a screenshot of a map container and uploads it to the server
 * before navigating to the link's href (e.g., PDF download).
 *
 * Usage:
 *   <%= link_to "Download PDF", some_path,
 *         data: {
 *           controller: "map-screenshot",
 *           map_screenshot_container_value: "map_idea_123",
 *           action: "click->map-screenshot#capture"
 *         } %>
 *
 * The map container must have a data-map-location-id attribute.
 */
export default class extends Controller {
  static values = {
    container: String // ID of the map container element
  }

  async capture(event) {
    if (!this.hasContainerValue || !this.containerValue) {
      // No map container specified, proceed normally
      return
    }

    const mapElement = document.getElementById(this.containerValue)

    if (!mapElement) {
      console.error("Map container not found:", this.containerValue)
      return
    }

    const trigger = event.currentTarget
    const href = trigger && trigger.href ? trigger.href : (this.element.href || null)

    if (!href) {
      console.error("Map screenshot: clicked element has no href")
      return
    }

    event.preventDefault()

    const mapLocationId = mapElement.dataset.mapLocationId
    if (!mapLocationId) {
      console.error("Map location ID not found on container")
      window.location.href = href
      return
    }

    try {
      const blob = await this.takeScreenshot(mapElement)
      await this.uploadScreenshot(blob, mapLocationId)
    } catch (error) {
      console.error("Screenshot failed:", error)
    } finally {
      window.location.href = href
      this.element.dispatchEvent(new CustomEvent("adm-button-with-progress:complete", { bubbles: true }))
    }
  }

  async takeScreenshot(element) {
    // For Mapbox/WebGL maps, use the native canvas directly
    const canvas = element.querySelector("canvas")
    if (canvas) {
      return this.screenshotFromCanvas(canvas)
    }

    // For Leaflet and other DOM-based maps, use dom-to-image-more
    return this.screenshotFromDom(element)
  }

  async screenshotFromDom(element) {
    const { toBlob } = await import("html-to-image")

    if (document.fonts && document.fonts.ready) {
      await document.fonts.ready
    }

    const restoreIcons = this.bakeMarkerIcons(element)
    const restoreGestureWarning = this.suppressGestureWarning(element)

    try {
      return await toBlob(element, {
        quality: 0.95,
        cacheBust: true,
        filter: this.excludeMapControls
      })
    } finally {
      restoreIcons()
      restoreGestureWarning()
    }
  }

  suppressGestureWarning(root) {
    const warningClasses = [
      "leaflet-gesture-handling-touch-warning",
      "leaflet-gesture-handling-scroll-warning"
    ]

    const containers = root.classList && root.classList.contains("leaflet-container")
      ? [root]
      : Array.from(root.querySelectorAll(".leaflet-container"))

    const removed = []

    containers.forEach(container => {
      warningClasses.forEach(cls => {
        if (container.classList.contains(cls)) {
          container.classList.remove(cls)
          removed.push([container, cls])
        }
      })
    })

    return () => removed.forEach(([container, cls]) => container.classList.add(cls))
  }

  bakeMarkerIcons(root) {
    const icons = root.querySelectorAll(".map-icon")
    const cleanups = []

    const styleEl = document.createElement("style")
    styleEl.textContent = ".js-screenshot-hide-pseudo::before { display: none !important; }"
    document.head.appendChild(styleEl)
    cleanups.push(() => styleEl.remove())

    icons.forEach(icon => this.bakeSingleMarkerIcon(icon, cleanups))

    return () => cleanups.forEach(fn => fn())
  }

  bakeSingleMarkerIcon(icon, cleanups) {
    const before = window.getComputedStyle(icon, "::before")
    const rawContent = before.content
    if (!rawContent || rawContent === "none" || rawContent === "normal") return

    const text = rawContent.replace(/^["']|["']$/g, "")
    if (!text) return

    const dataUrl = this.renderGlyphToDataUrl({
      text,
      fontFamily: before.fontFamily,
      fontWeight: before.fontWeight,
      fontSize: parseFloat(before.fontSize) || 14,
      color: before.color || "#fff"
    })
    if (!dataUrl) return

    const img = document.createElement("img")
    img.src = dataUrl
    img.style.cssText = "position: absolute; inset: 0; margin: auto; transform: rotate(45deg); pointer-events: none;"

    icon.classList.add("js-screenshot-hide-pseudo")
    icon.appendChild(img)

    cleanups.push(() => {
      icon.classList.remove("js-screenshot-hide-pseudo")
      img.remove()
    })
  }

  renderGlyphToDataUrl({ text, fontFamily, fontWeight, fontSize, color }) {
    try {
      const dpr = window.devicePixelRatio || 1
      const padding = 4
      const size = Math.ceil(fontSize) + padding * 2
      const canvas = document.createElement("canvas")
      canvas.width = size * dpr
      canvas.height = size * dpr
      const ctx = canvas.getContext("2d")
      ctx.scale(dpr, dpr)
      ctx.font = `${fontWeight} ${fontSize}px ${fontFamily}`
      ctx.fillStyle = color
      ctx.textAlign = "center"
      ctx.textBaseline = "middle"
      ctx.fillText(text, size / 2, size / 2)
      return canvas.toDataURL("image/png")
    } catch (e) {
      return null
    }
  }

  excludeMapControls(node) {
    if (!node.classList) return true

    const controlClasses = [
      "leaflet-control-container",
      "mapboxgl-control-container",
      "maplibregl-control-container",
      "ol-control"
    ]

    return !controlClasses.some(cls => node.classList.contains(cls))
  }

  screenshotFromCanvas(canvas) {
    return new Promise((resolve, reject) => {
      canvas.toBlob((blob) => {
        if (blob) {
          resolve(blob)
        } else {
          reject(new Error("Failed to generate blob from canvas"))
        }
      }, "image/jpeg", 0.95)
    })
  }

  async uploadScreenshot(blob, mapLocationId) {
    const formData = new FormData()
    formData.append("screenshot", blob, "screenshot.jpg")

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    const response = await fetch(`/map_locations/${mapLocationId}/update_screenshot`, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken
      },
      body: formData
    })

    if (!response.ok) {
      throw new Error(`Upload failed: ${response.status}`)
    }

    return response
  }
}

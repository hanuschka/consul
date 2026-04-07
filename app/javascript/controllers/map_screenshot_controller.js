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

    event.preventDefault()

    const mapLocationId = mapElement.dataset.mapLocationId
    if (!mapLocationId) {
      console.error("Map location ID not found on container")
      window.location.href = this.element.href
      return
    }

    try {
      const blob = await this.takeScreenshot(mapElement)
      await this.uploadScreenshot(blob, mapLocationId)
      window.location.href = this.element.href
    } catch (error) {
      console.error("Screenshot failed:", error)
      // Navigate anyway on error
      window.location.href = this.element.href
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

    return toBlob(element, {
      quality: 0.95,
      cacheBust: true
    })
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

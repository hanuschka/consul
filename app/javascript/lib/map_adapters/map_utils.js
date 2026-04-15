/**
 * Map Utilities
 *
 * Shared utility functions for map adapters.
 */

export function getBrandColor() {
  const style = getComputedStyle(document.documentElement)
  return style.getPropertyValue("--brand-color").trim() || "#004a83"
}

export function hexToRgba(hex, alpha) {
  hex = hex.replace("#", "")

  const r = parseInt(hex.substring(0, 2), 16)
  const g = parseInt(hex.substring(2, 4), 16)
  const b = parseInt(hex.substring(4, 6), 16)

  return `rgba(${r}, ${g}, ${b}, ${alpha})`
}

/**
 * Map Popup utilities for generating popup content and URLs
 */
export const MapPopup = {
  excludedProcesses: ["proposal", "deficiency_report", "idea", "projekt", "projekt_point_of_interest_pin"],

  generatePopupContent(data, resourceType, properties) {
    if (resourceType === "projekt_point_of_interest_pin") {
      return this.pointOfInterestPopupContent(data, properties)
    }
    return this.standardResourcePopupContent(data, resourceType)
  },

  getPopupDataUrl(resourceType, properties) {
    switch (resourceType) {
      case "proposal":
        return `/proposals/${properties.id}/json_data`
      case "deficiency_report":
        return `/deficiency_reports/${properties.id}/json_data`
      case "idea":
        return `/ideas/${properties.id}/json_data`
      case "projekt":
        return `/projekts/${properties.id}/json_data`
      case "investment":
        return `/investments/${properties.id}/json_data`
      case "projekt_point_of_interest_pin":
        return `/projekt_point_of_interest_pins/${properties.id}/json_data`
      default:
        return null
    }
  },

  getResourceUrl(data, resourceType) {
    switch (resourceType) {
      case "proposal":
        return `/proposals/${data.id}`
      case "deficiency_report":
        return `/deficiency_reports/${data.id}`
      case "idea":
        return `/ideas/${data.id}`
      case "projekt":
        return `/projekts/${data.id}`
      case "investment":
        return `/budgets/${data.budget_id}/investments/${data.id}`
      default:
        return null
    }
  },

  standardResourcePopupContent(data, resourceType) {
    const url = this.getResourceUrl(data, resourceType)
    let popupHtml = ""

    // Title
    if (url) {
      const finalUrl = data.projekt_phase_id ? `${url}?projekt_phase_id=${data.projekt_phase_id}` : url
      popupHtml = `<h5><a href="${finalUrl}">${data.title}</a></h5>`
    } else {
      popupHtml = `<h5>${data.title}</h5>`
    }

    // Image
    if (data.image_url) {
      popupHtml += `<img class="resource-map-popup-image" src="${data.image_url}" />`
    }

    // Labels and sentiments
    if ((data.labels?.length || 0) > 0 || (data.sentiment && Object.keys(data.sentiment).length > 0)) {
      popupHtml += '<div class="resource-map-popup-details resource-taggings">'

      if (data.labels?.length) {
        let labels = '<div class="projekt-labels">'
        data.labels.forEach(label => {
          labels += `<span class="projekt-label selected">`
          labels += `<span class="material-symbols-outlined" style="margin-right:4px;font-size:inherit;vertical-align:middle;">${label.icon}</span>`
          labels += label.name
          labels += `</span>`
        })
        labels += "</div>"
        popupHtml += labels
      }

      if (data.sentiment && Object.keys(data.sentiment).length) {
        let sentiments = '<div class="sentiments">'
        sentiments += `<span class="sentiment" style="background-color:${data.sentiment.backgroundColor};color:${data.sentiment.color}">${data.sentiment.name}</span>`
        sentiments += "</div>"
        popupHtml += sentiments
      }

      popupHtml += "</div>"
    }

    return `<div class="proposal-map-popup-content">${popupHtml}</div>`
  },

  pointOfInterestPopupContent(data, properties) {
    let popupHtml = `<h5 style="color:${properties.feature_color}">`
    popupHtml += `<i style="margin-right: 7px" class="icon-${properties.feature_icon_name}"></i>`
    popupHtml += properties.feature_category_name || "Point of Interest"
    popupHtml += "</h5>"
    return popupHtml
  }
}

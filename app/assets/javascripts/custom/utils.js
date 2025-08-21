App.Utils = {
  getBrandColor() {
    const style = getComputedStyle(document.documentElement)

    return style.getPropertyValue('--brand-color').trim() || '#004a83';
  },

  getLeafletMarkerHTML(color, iconClass) {
    color = color || App.Utils.getBrandColor();
    iconClass = iconClass || "circle";

    return L.divIcon({
      className: "map-marker",
      iconSize: [30, 30],
      iconAnchor: [15, 40],
      html: '<div class="map-icon icon-' + iconClass + '" style="background-color: ' + color + '"></div>'
    });
  }
}

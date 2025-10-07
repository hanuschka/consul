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
  },

  hexToRgba(hex, alpha) {
    hex = hex.replace('#', '');

    // Parse RGB values
    var r = parseInt(hex.substring(0, 2), 16);
    var g = parseInt(hex.substring(2, 4), 16);
    var b = parseInt(hex.substring(4, 6), 16);

    return 'rgba(' + r + ', ' + g + ', ' + b + ', ' + alpha + ')';
  }
}

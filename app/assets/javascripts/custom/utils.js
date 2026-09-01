App.Utils = {
  getBrandColor() {
    const style = getComputedStyle(document.documentElement)

    return style.getPropertyValue('--brand-color').trim() || '#004a83';
  },

  getLeafletMarkerHTML(color, iconClass, title) {
    color = color || App.Utils.getBrandColor();
    iconClass = iconClass || "circle";
    title = title || "Kartenmarkierung";

    return L.divIcon({
      className: "map-marker",
      iconSize: [30, 30],
      iconAnchor: [15, 40],
      html: '<div class="map-icon icon-' + iconClass + '" role="img" aria-label="' + title + '" style="background-color: ' + color + '"></div>'
    });
  },

  getMasterportalDotMarker(color) {
    color = color || App.Utils.getBrandColor();
    const size = 20;
    const half = size / 2;
    const title = "Masterportal-Pin";

    return L.divIcon({
      className: "masterportal-dot-marker",
      iconSize: [size, size],
      iconAnchor: [half, half],
      popupAnchor: [0, -half],
      html: '<span role="img" aria-label="' + title + '" title="' + title + '" style="background-color: ' + color + '"></span>'
    });
  },

  getVirtualcityMarkerHTML(color, iconClass) {
    var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 -10 384 522">' +
                 '<path fill="' + this.hexToRgba(color, 0.8) + '" stroke="#fff" stroke-width="20" d="M172.3 501.7C27 291 0 269.4 0 192 0 86 86 0 192 0s192 86 192 192c0 77.4-27 99-172.3 309.7-9.5 13.8-29.9 13.8-39.5 0z" />' +
              '</svg>';

    var encodedSvg = btoa(unescape(encodeURIComponent(svg)));

    return 'data:image/svg+xml;base64,' + encodedSvg;
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

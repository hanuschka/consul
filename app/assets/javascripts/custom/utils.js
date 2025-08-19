App.Utils = {
  getBrandColor() {
    const style = getComputedStyle(document.documentElement)

    return style.getPropertyValue('--brand-color').trim() || '#004a83';
  },

  getLeafletMarkerHTML(feature, adminEditor) {
    var color, iconClass;

    if (adminEditor) {
      color = "#ff0000";
    } else if (feature && feature.properties && feature.properties.color) {
      color = feature.properties.color
    } else {
      color = App.Utils.getBrandColor();
    }

    if (feature && feature.properties && feature.properties.fa_icon_class) {
      iconClass = feature.properties.fa_icon_class;
    } else {
      iconClass = "circle";
    }

    return L.divIcon({
      className: "map-marker",
      iconSize: [30, 30],
      iconAnchor: [15, 40],
      html: '<div class="map-icon icon-' + iconClass + '" style="background-color: ' + color + '"></div>'
    });
  }
}

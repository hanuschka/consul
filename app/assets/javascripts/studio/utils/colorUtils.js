App.Studio.utils.LIGHT_TEXT_COLOR = "#ffffff";
App.Studio.utils.DARK_TEXT_COLOR = "#1a2e44";

// White or the templates' near-black text color, whichever contrasts more
// with a computed color such as getComputedStyle(element).backgroundColor.
App.Studio.utils.readableTextColor = function(computedColor) {
  const luminance = App.Studio.utils.relativeLuminance(computedColor);
  const darkLuminance = App.Studio.utils.relativeLuminance("rgb(26, 46, 68)");
  const contrastWithLight = 1.05 / (luminance + 0.05);
  const contrastWithDark = (luminance + 0.05) / (darkLuminance + 0.05);

  if (contrastWithLight >= contrastWithDark) return App.Studio.utils.LIGHT_TEXT_COLOR

  return App.Studio.utils.DARK_TEXT_COLOR
}

// WCAG relative luminance of an "rgb(r, g, b)" or "rgba(r, g, b, a)" string.
App.Studio.utils.relativeLuminance = function(computedColor) {
  const channels = (computedColor.match(/[\d.]+/g) || ["0", "0", "0"])
    .slice(0, 3)
    .map((channel) => App.Studio.utils.linearChannel(parseFloat(channel) / 255));

  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]
}

App.Studio.utils.linearChannel = function(channel) {
  return channel <= 0.03928 ? channel / 12.92 : Math.pow((channel + 0.055) / 1.055, 2.4)
}

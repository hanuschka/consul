const ICON_FONT = '24px "Material Symbols Outlined"'

function revealIcons() {
  document.documentElement.classList.add("fonts-loaded")
}

export function revealIconsWhenFontLoaded() {
  if (!document.fonts) {
    revealIcons()
    return
  }

  document.fonts.load(ICON_FONT).then(revealIcons, revealIcons)
}

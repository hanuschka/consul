App.Utils = {
  getBrandColor() {
    const style = getComputedStyle(document.documentElement)

    return style.getPropertyValue('--brand-color').trim() || '#004a83';
  }
}

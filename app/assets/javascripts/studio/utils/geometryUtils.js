App.Studio.utils.boxesOverlap = function(firstBox, secondBox) {
  return firstBox.left < secondBox.right && secondBox.left < firstBox.right &&
    firstBox.top < secondBox.bottom && secondBox.top < firstBox.bottom
}

App.Studio.utils.clampCenterInside = function(center, halfWidth, containerWidth) {
  const maxCenter = Math.max(halfWidth, containerWidth - halfWidth)

  return Math.min(Math.max(center, halfWidth), maxCenter)
}

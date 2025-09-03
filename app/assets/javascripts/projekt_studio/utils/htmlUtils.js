ProjektStudio.utils.focusContentEditableElement = function(element) {
  element.focus()

  const range = document.createRange();
  range.selectNodeContents(element);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
}

ProjektStudio.utils.htmlToDomElement = function(html) {
  const div = document.createElement('div');
  div.innerHTML = html;

  return div
}


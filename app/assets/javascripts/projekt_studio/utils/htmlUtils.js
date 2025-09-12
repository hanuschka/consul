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

const voidElements = [
  "base", "br", "col", "embed", "hr",
  "img", "link", "param",
  "source", "track", "wbr"
];

ProjektStudio.utils.validateHTML = function(htmlContent) {
  const parser = new DOMParser();
  const parsedDoc = parser.parseFromString(htmlContent, 'text/html');

  const parserError = parsedDoc.querySelector("parsererror");
  if (parserError) {
    return {
      isValid: false,
      message: "Parsing error detected in HTML.",
      issues: [parserError.textContent]
    };
  }

  const originalTags = htmlContent.match(/<\s*([a-zA-Z0-9]+)\b[^>]*>/g) || [];
  const originalTagNames = originalTags.map(tag => tag.match(/<\s*([a-zA-Z0-9]+)/)[1]);
  const closedTags = htmlContent.match(/<\/\s*([a-zA-Z0-9]+)\s*>/g) || [];
  const closedTagNames = closedTags.map(tag => tag.match(/<\/\s*([a-zA-Z0-9]+)/)[1]);

  voidElements.forEach((tagNameToRemove) => {
    if (originalTagNames.includes(tagNameToRemove)) {
      originalTagNames.splice(originalTagNames.indexOf(tagNameToRemove), 1);
    }
  })

  const tagStack = [];
  const issues = [];

  originalTagNames.forEach(tag => tagStack.push(tag));

  closedTagNames.forEach(tag => {
    if (tagStack.includes(tag)) {
      tagStack.splice(tagStack.indexOf(tag), 1);
    } else {
      issues.push(`Unexpected closing tag </${tag}> found.`);
    }
  });

  if (tagStack.length > 0) {
    issues.push(`Unclosed tags: ${tagStack.map(tag => `<${tag}>`).join(', ')}`);
  }

  if (issues.length > 0) {
    return {
      isValid: false,
      message: "HTML structure has issues. See details below.",
      issues: issues
    };
  }

  return {
    isValid: true,
    message: "HTML is valid."
  };
}

ProjektStudio.utils.focusContentEditableElement = function(element) {
  element.focus()

  const range = document.createRange();
  range.selectNodeContents(element);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
}

// ProjektStudio.utils.selectEndOfContentEditable = function(element) {
//   // Focus the element first
//   element.focus();

//   // Create a range and position it at the end of the content
//   const range = document.createRange();
//   const selection = window.getSelection();

//   // Remove any existing selections
//   selection.removeAllRanges();

//   // If the element has text content, position cursor at the end
//   if (element.textContent.length > 0) {
//     range.selectNodeContents(element);
//     range.collapse(false); // false means collapse to end
//   } else {
//     // If element is empty, just position at the start
//     range.setStart(element, 0);
//     range.collapse(true);
//   }

//   // Apply the selection
//   selection.addRange(range);
// }

ProjektStudio.utils.htmlToDomElement = function(html) {
  const div = document.createElement('div');
  div.innerHTML = html;

  return div
}

ProjektStudio.utils.htmlToSingleDomElement = function(html) {
  return ProjektStudio.utils.htmlToDomElement(html).firstElementChild;
}

const voidElements = [
  "area", "base", "br", "col", "embed", "hr",
  "img", "input", "link", "meta", "param",
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
  const allTagNames = originalTags.map(tag => tag.match(/<\s*([a-zA-Z0-9]+)/)[1]);
  const closedTags = htmlContent.match(/<\/\s*([a-zA-Z0-9]+)\s*>/g) || [];
  const closedTagNames = closedTags.map(tag => tag.match(/<\/\s*([a-zA-Z0-9]+)/)[1]);

  // Filter out all void elements (they don't require closing tags)
  const originalTagNames = allTagNames.filter(tag => !voidElements.includes(tag))

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

ProjektStudio.utils.removeChildHtmlAttributes = function(element, attributes = []) {
  attributes.forEach((attribute) => {
    element
      .querySelectorAll(`[${attribute}]`)
      .forEach(el => el.removeAttribute(attribute));
  })
}

ProjektStudio.utils.hasBlockChildren = (element) => {
  const blockSelectors = [
    "div", "p", "ul", "ol", "li", "section", "article", "header", "footer", "aside", "nav",
    "h1","h2","h3","h4","h5","h6", "blockquote", "pre", "img"
  ];

  return element.querySelector(blockSelectors.join(", ")) !== null;
};

ProjektStudio.utils.hasNoBlockChildren = (element) => {
  return !ProjektStudio.utils.hasBlockChildren(element);
};


ProjektStudio.utils.sanitizeHtml = (input, { allowedTags = [], allowedAttributes = [] }) => {
  const ALLOWED_TAGS = new Set(allowedTags.map(tag => tag.toUpperCase())); // uppercase tagNames
  const ALLOWED_ATTRS = new Set(allowedAttributes); // only class allowed

  const container = document.createElement('div');
  container.innerHTML = input;

  // remove comments
  const commentWalker = document.createTreeWalker(container, NodeFilter.SHOW_COMMENT, null, false);
  const comments = [];
  let c;
  while ((c = commentWalker.nextNode())) comments.push(c);
  comments.forEach(node => node.remove());

  // sanitize elements
  const elements = Array.from(container.querySelectorAll('*'));
  for (const el of elements) {
    if (!ALLOWED_TAGS.has(el.tagName)) {
      // unwrap disallowed tag (keep children)
      while (el.firstChild) el.parentNode.insertBefore(el.firstChild, el);
      el.remove();
    } else {
      // allowed: strip all attributes except "class"
      const attrs = Array.from(el.attributes);
      for (const a of attrs) {
        if (!ALLOWED_ATTRS.has(a.name.toLowerCase())) {
          el.removeAttribute(a.name);
        }
      }
    }
  }

  return container.innerHTML;
}

ProjektStudio.utils.formatHTML = function(html) {
  let formatted = '';
  let indent = 0;
  const indentString = '  '; // 2 spaces

  // Split by tags
  const tags = html.split(/(<\/?[^>]+>)/g).filter(part => part.trim());

  tags.forEach(tag => {
    const isClosingTag = tag.match(/^<\/\w+>/);
    const isSelfClosing = tag.match(/\/>$/) || tag.match(/^<(br|hr|img|input|link|meta|area|base|col|embed|param|source|track|wbr)/i);
    const isOpeningTag = tag.match(/^<\w+/) && !isSelfClosing;

    // Decrease indent for closing tags before adding line
    if (isClosingTag) {
      indent = Math.max(0, indent - 1);
    }

    // Add indentation
    if (tag.startsWith('<')) {
      formatted += indentString.repeat(indent) + tag.trim() + '\n';
    } else if (tag.trim()) {
      // Text content
      formatted += indentString.repeat(indent) + tag.trim() + '\n';
    }

    // Increase indent after opening tags
    if (isOpeningTag) {
      indent++;
    }
  });

  return formatted.trim();
}

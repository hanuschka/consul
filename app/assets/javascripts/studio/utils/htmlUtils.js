App.Studio.utils.focusContentEditableElement = function(element, options = {}) {
  element.focus({ preventScroll: options.preventScroll || true })

  const range = document.createRange();
  range.selectNodeContents(element);
  range.collapse(false);
  const selection = window.getSelection();
  selection.removeAllRanges();
  selection.addRange(range);
}

App.Studio.utils.htmlToDomElement = function(html) {
  const div = document.createElement('div');
  div.innerHTML = html;

  return div
}

App.Studio.utils.htmlToSingleDomElement = function(html) {
  return App.Studio.utils.htmlToDomElement(html).firstElementChild;
}

const voidElements = [
  "area", "base", "br", "col", "embed", "hr",
  "img", "input", "link", "meta", "param",
  "source", "track", "wbr"
];

App.Studio.utils.validateHTML = function(htmlContent) {
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

  const originalTags = htmlContent.match(/<\s*([a-zA-Z0-9-]+)\b[^>]*>/g) || [];
  const allTagNames = originalTags.map(tag => tag.match(/<\s*([a-zA-Z0-9-]+)/)[1]);
  const closedTags = htmlContent.match(/<\/\s*([a-zA-Z0-9-]+)\s*>/g) || [];
  const closedTagNames = closedTags.map(tag => tag.match(/<\/\s*([a-zA-Z0-9-]+)/)[1]);

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

App.Studio.utils.removeChildHtmlAttributes = function(element, attributes = []) {
  attributes.forEach((attribute) => {
    element
      .querySelectorAll(`[${attribute}]`)
      .forEach(el => el.removeAttribute(attribute));
  })
}

App.Studio.utils.hasBlockChildren = (element) => {
  const blockSelectors = [
    "div", "p", "ul", "ol", "li", "section", "article", "header", "footer", "aside", "nav",
    "h1","h2","h3","h4","h5","h6", "blockquote", "pre", "img"
  ];

  return element.querySelector(blockSelectors.join(", ")) !== null;
};

App.Studio.utils.hasNoBlockChildren = (element) => {
  return !App.Studio.utils.hasBlockChildren(element);
};


App.Studio.utils.sanitizeHtml = (input, { allowedTags = [], allowedAttributes = [] }) => {
  const ALLOWED_TAGS = new Set(allowedTags.map(tag => tag.toUpperCase())); // uppercase tagNames
  const ALLOWED_ATTRS = new Set(allowedAttributes); // only class allowed
  const URL_ATTRS = new Set(["href", "src", "action", "formaction", "xlink:href", "data"]);
  const DANGEROUS_URL = /^\s*(javascript|vbscript|data):/i;

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
        const name = a.name.toLowerCase();

        if (!ALLOWED_ATTRS.has(name)) {
          el.removeAttribute(a.name);
          continue;
        }

        if (URL_ATTRS.has(name) && DANGEROUS_URL.test(a.value)) {
          el.removeAttribute(a.name);
        }
      }
    }
  }

  return container.innerHTML;
}

// Mirror of AdminWYSIWYGSanitizer (lib/admin_wysiwyg_sanitizer.rb + lib/wysiwyg_sanitizer.rb).
// If you change these lists, update the Ruby class to match.
App.Studio.utils.ADMIN_WYSIWYG_ALLOWLIST = {
  allowedTags: [
    "div", "p", "ul", "ol", "li", "blockquote", "br", "hr", "a",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "b", "strong", "em", "u", "s", "sub", "sup", "span", "img",
    "table", "caption", "thead", "tr", "th", "tbody", "td", "abbr",
    "i", "figure", "figcaption", "section", "nav",
    "iframe", "object", "param", "embed",
    "input", "label", "form", "button", "textarea", "oembed"
  ],
  allowedAttributes: [
    "href", "style", "target", "class", "id", "name", "alt", "src",
    "align", "border", "cellpadding", "cellspacing", "summary", "scope",
    "title", "allowfullscreen", "frameborder", "height", "width",
    "data-src", "data-path",
    "min-height", "longdesc", "scrolling", "allow", "value", "dir",
    "action", "role", "tabindex", "type", "for",
    "data-toggle", "aria-label", "aria-hidden", "placeholder",
    "data-slider", "data-initial-start", "data-end",
    "data-slider-handle", "data-slider-fill",
    "data-dropdown-menu", "data-dropdown", "data-auto-focus",
    "data-magellan", "data-magellan-target",
    "data-sticky-container", "data-sticky", "data-margin-top",
    "data-anchor", "data-sticky-on",
    "data-deep-link", "data-update-history", "data-deep-linking",
    "data-animation-duration", "data-animation-easing",
    "data-threshold", "data-active-class", "data-offset",
    "data-drilldown",
    "data-accordion", "data-accordion-item", "data-tab-content",
    "data-allow-all-closed", "data-accordion-menu",
    "data-reveal", "data-open", "data-close",
    "data-tabs", "aria-selected", "data-tabs-target", "data-tabs-content",
    "data-orbit", "data-slide", "data-slide-active-label",
    "aria-valuenow", "aria-valuemin", "aria-valuemax", "aria-valuetext",
    "data-tooltip", "data-hint", "data-hint-position", "data-use-m-u-i",
    "data-anim-in-from-left", "data-anim-in-from-right",
    "data-anim-out-to-left", "data-anim-out-to-right",
    "data-options",
    "data-equalizer", "data-equalizer-watch", "data-equalize-on",
    "data-target",
    "data-map", "data-map-center-latitude", "data-map-center-longitude",
    "data-map-zoom", "data-admin-editor", "data-show-admin-shape",
    "data-admin-shape", "data-parent-class", "data-map-layers",
    "data-map-resource", "data-map-phase-id",
    "data-show-more-text", "data-show-less-text",
    "data-pswp-width", "data-pswp-height",
    "data-turbolinks", "data-box-shadow", "data-glightbox",
    "url"
  ]
};

App.Studio.utils.sanitizeAdminHtml = function(html) {
  return App.Studio.utils.sanitizeHtml(html, App.Studio.utils.ADMIN_WYSIWYG_ALLOWLIST);
}

// Map embeds are hydrated into live maps for display in the studio, but the
// saved body must always keep the {{projekt_map}} token so the server
// re-renders the map on each request. This strips any hydrated map markup and
// restores the token before a content block is persisted.
App.Studio.utils.resetMapEmbeds = function(html) {
  if (!html || html.indexOf("js-projekt-map-embed") === -1) return html;

  const container = App.Studio.utils.htmlToDomElement(html);

  container.querySelectorAll(".js-projekt-map-embed").forEach((embed) => {
    embed.querySelectorAll(".projekt-map-shortcode").forEach((map) => map.remove());
    embed.querySelectorAll(".js-map-height-control").forEach((control) => control.remove());
    embed.querySelectorAll(".js-map-source-control").forEach((control) => control.remove());

    if (embed.innerHTML.indexOf("{{projekt_map}}") === -1) {
      embed.appendChild(document.createTextNode("{{projekt_map}}"));
    }
  });

  return container.innerHTML;
}

App.Studio.utils.formatHTML = function(html) {
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

// Updates the title text of the <rich-tooltip> that wraps a given trigger
// element. Used by stateful toggle buttons whose tooltip text changes with
// their state (e.g. show/hide phase, set/unset default phase, sidebar section).
App.Studio.utils.updateRichTooltipTitle = function(trigger, newTitle) {
  const tooltip = trigger.closest("rich-tooltip");

  if (!tooltip) return

  const titleEl = tooltip.querySelector(".rich-tooltip-content--title");

  if (titleEl) titleEl.textContent = newTitle;
}

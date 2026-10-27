App.Studio.ContentBlocks.SimpleEditMode.TextFormat = {
  formats: {
    bold: { tagName: "strong", matchingTagNames: ["strong", "b"] },
    italic: { tagName: "em", matchingTagNames: ["em", "i"] }
  },

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-toggle-bold", this.toggleBold.bind(this));
    $document.on("click", ".js-content-block-toggle-italic", this.toggleItalic.bind(this));
  },

  toggleBold(e) {
    this.toggleFormat(e, this.formats.bold);
  },

  toggleItalic(e) {
    this.toggleFormat(e, this.formats.italic);
  },

  toggleFormat(e, format) {
    e.preventDefault();

    const selection = window.getSelection();
    if (!selection.rangeCount || selection.isCollapsed) {
      return;
    }

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(container);
    if (!contentBlockWrapper || !contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      return;
    }

    const surroundingContentBlock = container.closest(".js-content-block");
    if (!surroundingContentBlock) {
      return;
    }

    const newRange = this.applyFormatting(range, format);
    if (newRange) {
      selection.removeAllRanges();
      selection.addRange(newRange);
    }
  },

  applyFormatting(range, format) {
    const container = range.commonAncestorContainer;
    const parentElement = container.nodeType === 3 ? container.parentNode : container;

    const formattedParent = this.findFormattedParent(parentElement, format);

    if (formattedParent) {
      return this.unwrapFormattedElement(formattedParent, range, format);
    } else {
      const selectedContent = range.extractContents();
      const formattedElement = this.wrapInFormatElement(selectedContent, format);
      range.insertNode(formattedElement);

      const newRange = document.createRange();
      newRange.selectNodeContents(formattedElement);
      return newRange;
    }
  },

  findFormattedParent(element, format) {
    let current = element;
    while (current && current.nodeType === 1) {
      const tagName = current.nodeName.toLowerCase();
      if (format.matchingTagNames.includes(tagName)) {
        return current;
      }
      if (current.getAttribute("contenteditable") === "true") {
        break;
      }
      current = current.parentNode;
    }
    return null;
  },

  unwrapFormattedElement(formattedElement, range, format) {
    const selectedText = window.getSelection().toString();

    if (selectedText === formattedElement.textContent) {
      const nodes = Array.from(formattedElement.childNodes);
      const fragment = document.createDocumentFragment();
      fragment.append(...nodes);
      formattedElement.parentNode.replaceChild(fragment, formattedElement);
      return this.createRangeAround(nodes);
    }

    const beforeRange = document.createRange();
    beforeRange.setStart(formattedElement.firstChild || formattedElement, 0);
    beforeRange.setEnd(range.startContainer, range.startOffset);

    const afterRange = document.createRange();
    afterRange.setStart(range.endContainer, range.endOffset);
    afterRange.setEnd(
      formattedElement.lastChild || formattedElement,
      formattedElement.lastChild ? formattedElement.lastChild.textContent.length : 0
    );

    const selectedContent = range.extractContents();
    const beforeContent = beforeRange.cloneContents();
    const afterContent = afterRange.cloneContents();

    const fragment = document.createDocumentFragment();

    if (beforeContent.textContent) {
      fragment.appendChild(this.wrapInFormatElement(beforeContent, format));
    }

    const selectedNodes = Array.from(selectedContent.childNodes);
    fragment.append(...selectedNodes);

    if (afterContent.textContent) {
      fragment.appendChild(this.wrapInFormatElement(afterContent, format));
    }

    formattedElement.parentNode.replaceChild(fragment, formattedElement);
    return this.createRangeAround(selectedNodes);
  },

  createRangeAround(nodes) {
    const range = document.createRange();
    if (nodes.length > 0) {
      range.setStartBefore(nodes[0]);
      range.setEndAfter(nodes[nodes.length - 1]);
    }
    return range;
  },

  wrapInFormatElement(content, format) {
    const element = document.createElement(format.tagName);
    element.appendChild(content);
    return element;
  }
}

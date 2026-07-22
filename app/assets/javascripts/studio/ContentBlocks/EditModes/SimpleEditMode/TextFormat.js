App.Studio.ContentBlocks.SimpleEditMode.TextFormat = {
  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-toggle-bold", this.toggleBold.bind(this));
  },

  toggleBold(e) {
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

    const newRange = this.applyBoldFormatting(range);
    if (newRange) {
      selection.removeAllRanges();
      selection.addRange(newRange);
    }
  },

  applyBoldFormatting(range) {
    const container = range.commonAncestorContainer;
    const parentElement = container.nodeType === 3 ? container.parentNode : container;

    const boldParent = this.findBoldParent(parentElement);

    if (boldParent) {
      return this.unwrapBoldElement(boldParent, range);
    } else {
      const selectedContent = range.extractContents();
      const strongElement = document.createElement("strong");
      strongElement.appendChild(selectedContent);
      range.insertNode(strongElement);

      const newRange = document.createRange();
      newRange.selectNodeContents(strongElement);
      return newRange;
    }
  },

  findBoldParent(element) {
    let current = element;
    while (current && current.nodeType === 1) {
      const tagName = current.nodeName.toLowerCase();
      if (tagName === "strong" || tagName === "b") {
        return current;
      }
      if (current.getAttribute("contenteditable") === "true") {
        break;
      }
      current = current.parentNode;
    }
    return null;
  },

  unwrapBoldElement(boldElement, range) {
    const selectedText = window.getSelection().toString();

    if (selectedText === boldElement.textContent) {
      const nodes = Array.from(boldElement.childNodes);
      const fragment = document.createDocumentFragment();
      fragment.append(...nodes);
      boldElement.parentNode.replaceChild(fragment, boldElement);
      return this.createRangeAround(nodes);
    }

    const beforeRange = document.createRange();
    beforeRange.setStart(boldElement.firstChild || boldElement, 0);
    beforeRange.setEnd(range.startContainer, range.startOffset);

    const afterRange = document.createRange();
    afterRange.setStart(range.endContainer, range.endOffset);
    afterRange.setEnd(
      boldElement.lastChild || boldElement,
      boldElement.lastChild ? boldElement.lastChild.textContent.length : 0
    );

    const selectedContent = range.extractContents();
    const beforeContent = beforeRange.cloneContents();
    const afterContent = afterRange.cloneContents();

    const fragment = document.createDocumentFragment();

    if (beforeContent.textContent) {
      fragment.appendChild(this.wrapInStrong(beforeContent));
    }

    const selectedNodes = Array.from(selectedContent.childNodes);
    fragment.append(...selectedNodes);

    if (afterContent.textContent) {
      fragment.appendChild(this.wrapInStrong(afterContent));
    }

    boldElement.parentNode.replaceChild(fragment, boldElement);
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

  wrapInStrong(content) {
    const strong = document.createElement("strong");
    strong.appendChild(content);
    return strong;
  }
}

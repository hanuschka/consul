ProjektStudio.ContentBlock.SimpleEditMode.TextFormat = {
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

    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(container);
    if (!contentBlockWrapper || !contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      return;
    }

    const surroundingContentBlock = container.closest(".js-projekt-content-block");
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
    const selection = window.getSelection();
    const selectedText = selection.toString();
    const fullText = boldElement.textContent;

    if (selectedText === fullText) {
      const nodes = Array.from(boldElement.childNodes);
      const fragment = document.createDocumentFragment();
      nodes.forEach(node => fragment.appendChild(node));
      boldElement.parentNode.replaceChild(fragment, boldElement);

      const newRange = document.createRange();
      if (nodes.length > 0) {
        newRange.setStartBefore(nodes[0]);
        newRange.setEndAfter(nodes[nodes.length - 1]);
      }
      return newRange;
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

    if (beforeContent.textContent.length > 0) {
      const beforeStrong = document.createElement("strong");
      beforeStrong.appendChild(beforeContent);
      fragment.appendChild(beforeStrong);
    }

    const selectedNodes = Array.from(selectedContent.childNodes);
    selectedNodes.forEach(node => fragment.appendChild(node));

    if (afterContent.textContent.length > 0) {
      const afterStrong = document.createElement("strong");
      afterStrong.appendChild(afterContent);
      fragment.appendChild(afterStrong);
    }

    boldElement.parentNode.replaceChild(fragment, boldElement);

    const newRange = document.createRange();
    if (selectedNodes.length > 0) {
      newRange.setStartBefore(selectedNodes[0]);
      newRange.setEndAfter(selectedNodes[selectedNodes.length - 1]);
    }
    return newRange;
  }
}

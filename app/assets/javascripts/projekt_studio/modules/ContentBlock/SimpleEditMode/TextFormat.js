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

    this.applyBoldFormatting(range);
    selection.removeAllRanges();
  },

  applyBoldFormatting(range) {
    const container = range.commonAncestorContainer;
    const parentElement = container.nodeType === 3 ? container.parentNode : container;

    const boldParent = this.findBoldParent(parentElement);

    if (boldParent) {
      this.unwrapBoldElement(boldParent, range);
    } else {
      const selectedContent = range.extractContents();
      const strongElement = document.createElement("strong");
      strongElement.appendChild(selectedContent);
      range.insertNode(strongElement);
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
      const fragment = document.createDocumentFragment();
      while (boldElement.firstChild) {
        fragment.appendChild(boldElement.firstChild);
      }
      boldElement.parentNode.replaceChild(fragment, boldElement);
    } else {
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

      fragment.appendChild(selectedContent);

      if (afterContent.textContent.length > 0) {
        const afterStrong = document.createElement("strong");
        afterStrong.appendChild(afterContent);
        fragment.appendChild(afterStrong);
      }

      boldElement.parentNode.replaceChild(fragment, boldElement);
    }
  }
}

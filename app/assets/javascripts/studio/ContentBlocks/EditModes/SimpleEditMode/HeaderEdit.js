App.Studio.ContentBlocks.SimpleEditMode.HeaderEdit = {
  initialize() {
    this.initEventListeners();
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-header-option", this.handleHeaderSelect.bind(this));
  },

  handleHeaderSelect(e) {
    e.preventDefault();
    e.stopPropagation();

    const $item = $(e.currentTarget);
    const headerType = $item.data("header-type");
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

    this.applyHeaderFormatting(container, headerType);
    this.updateDropdownLabel(contentBlockWrapper, headerType);

    const $dropdown = $item.closest(".js-dropdown-select-menu");
    App.DropdownSelectMenuComponent.closeDropdown($dropdown);
  },

  applyHeaderFormatting(element, headerType) {
    const selection = window.getSelection();
    if (!selection.rangeCount) {
      return;
    }

    const range = selection.getRangeAt(0);
    const selectedText = range.toString().trim();

    if (!selectedText) {
      return;
    }

    const selectedContent = range.extractContents();
    let newElement;

    if (headerType === "none") {
      newElement = document.createElement("p");
    } else {
      newElement = document.createElement(headerType);
    }

    newElement.appendChild(selectedContent);
    newElement.contentEditable = true;

    range.insertNode(newElement);

    const newRange = document.createRange();
    newRange.selectNodeContents(newElement);
    selection.removeAllRanges();
    selection.addRange(newRange);

    newElement.focus();
  },

  findEditableParent(element) {
    let current = element;
    while (current && current.nodeType === 1) {
      if (current.getAttribute("contenteditable") === "true") {
        return current;
      }
      current = current.parentNode;
    }
    return null;
  },

  updateDropdownLabel(contentBlockWrapper, headerType) {
    const $dropdown = $(contentBlockWrapper).find(".js-content-block-header-dropdown");
    const $toggle = $dropdown.find(".js-dropdown-select-menu-toggle");

    const labels = {
      "h2": "H2",
      "h3": "H3",
      "none": "Text"
    };

    $toggle.text(labels[headerType] || "Text");
  },

  getSelectedElementType(contentBlockWrapper) {
    const selection = window.getSelection();
    if (!selection.rangeCount) {
      return "none";
    }

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer;
    const element = container.nodeType === 1 ? container : container.parentNode;
    const editableElement = this.findEditableParent(element);

    if (!editableElement) {
      return "none";
    }

    const tagName = editableElement.tagName.toLowerCase();
    if (["h2", "h3"].includes(tagName)) {
      return tagName;
    }

    return "none";
  },

  updateDropdownFromSelection(contentBlockWrapper) {
    const selectedType = this.getSelectedElementType(contentBlockWrapper);
    this.updateDropdownLabel(contentBlockWrapper, selectedType);
  }
};

ProjektStudio.ContentBlockSimpleEdit.LinkEdit = {
  savedSelection: null,
  currentBlock: null,

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndWrapper = ProjektStudio.ContentBlocks.getContentBlockAndWrapper.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-content-block-add-link", this.addLink.bind(this));
    $document.on("selectionchange", this.handleTextSelectionChange.bind(this))
    $document.on("click", ".js-content-block-accept-link-edit", this.acceptLinkEdit.bind(this));
    $document.on("click", ".js-content-block-cancel-link-edit", this.cancelLinkEdit.bind(this));
  },

  restoreSelection() {
    if (this.savedSelection) {
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(this.savedSelection);
    }
  },

  handleTextSelectionChange() {
    const sel = window.getSelection();

    if (!sel.rangeCount) {
      return;
    }

    const range = sel.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(container)
    if (!contentBlockWrapper) return

    const button = contentBlockWrapper.querySelector(".js-content-block-add-link")
    const hasText = sel.toString().trim().length > 0;

    const surroundingContentBlock = container.closest(".js-projekt-content-block")

    if (!surroundingContentBlock) {
      button.disabled = true
      return
    }

    $(".js-content-block-add-link").prop("disabled", true);

    if (contentBlockWrapper) {
      button.disabled = !hasText
    }
  },

  saveSelection() {
    const sel = window.getSelection();

    if (sel.rangeCount > 0) {
      this.savedSelection = sel.getRangeAt(0);
    }
  },

  addLink(e) {
    const sel = window.getSelection();

    if (!sel.rangeCount) return;

    const range = sel.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    // const { contentBlockWrapper } = this.getContentBlockAndWrapper(container)
    // if (!contentBlockWrapper) return
    // const button = contentBlockWrapper.querySelector(".js-content-block-add-link")
    // const hasText = sel.toString().trim().length > 0;
    const surroundingContentBlock = container.closest(".js-projekt-content-block")

    if (!surroundingContentBlock) {
      return
    }

    this.saveSelection();
    // this.currentBlock = $block;

    const rect = range.getBoundingClientRect();
    $(".js-content-block-link-popup").css({
      top: window.scrollY + rect.bottom + "px",
      left: window.scrollX + rect.left + "px",
      display: "block"
    });

    $(".js-content-block-link-popup .js-content-block-url-input").focus();
  },

  acceptLinkEdit() {
    const $urlInput = $(".js-content-block-url-input")
    const url = $urlInput.val().trim();
    if (!url) {
      alert("Bitte geben Sie eine URL ein");
      return;
    }

    const blankCheckbox = document.querySelector(".js-content-block-url-black-checkbox")

    this.restoreSelection();

    if (this.savedSelection) {
      const a = document.createElement("a");
      a.href = url;
      if (blankCheckbox.checked) {
        a.target = "_blank";
      }
      a.appendChild(this.savedSelection.extractContents());
      this.savedSelection.insertNode(a);
    }

    $(".js-content-block-link-popup").hide();
    $urlInput.val("");
    blankCheckbox.checked = true;

    this.savedSelection = null;
    this.currentBlock = null;
  },

  cancelLinkEdit() {
    $(".js-content-block-link-popup").hide();
    this.savedSelection = null;
    this.currentBlock = null;
  },
}

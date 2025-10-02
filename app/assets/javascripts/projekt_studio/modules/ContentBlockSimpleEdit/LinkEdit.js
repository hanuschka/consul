ProjektStudio.ContentBlockSimpleEdit.LinkEdit = {
  savedSelection: null,
  currentContentBlockWrapper: null,
  savedLinkIdToEdit: null,

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
    $document.on("mouseover", ".js-projekt-content-block-wrapper.-simple-edit-mode .js-projekt-content-block a",
      this.showLinkEditButton.bind(this)
    );
    $document.on("mouseleave", ".js-content-block-link-wrapper", this.hideLinkEditButton.bind(this));
    $document.on("click", ".js-content-block-edit-link", this.editLink.bind(this))
  },

  showLinkEditButton(e) {
    const link = e.currentTarget
    if (link.parentElement.classList.contains("js-content-block-link-wrapper")) {
      return
    }
    if (["glightbox", "glightbox-disabled"].some(c => link.classList.contains(c))) {
      return
    }

    const linkWrapper = document.createElement("div")
    linkWrapper.classList.add("content-block-link-wrapper", "js-content-block-link-wrapper")

    linkWrapper.innerHTML = `
      ${link.outerHTML}
      <button type="button" title="Link bearbeiten" class="content-block-edit-link-button js-content-block-edit-link">
        <i class="fas fa-pencil-alt"></i>
      </button>
    `

    link.outerHTML =  linkWrapper.outerHTML
  },

  hideLinkEditButton(e) {
    const wrapper = e.currentTarget
    const a = wrapper.querySelector("a")
    wrapper.outerHTML = a.outerHTML
  },

  restoreSelection() {
    if (this.savedSelection) {
      const selection = window.getSelection();
      selection.removeAllRanges();
      selection.addRange(this.savedSelection);
    }
  },

  handleTextSelectionChange() {
    const selection = window.getSelection();

    if (!selection.rangeCount) {
      return;
    }

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(container)
    if (!contentBlockWrapper) return

    const button = contentBlockWrapper.querySelector(".js-content-block-add-link")
    const hasText = selection.toString().trim().length > 0;

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
    const selection = window.getSelection();

    if (selection.rangeCount > 0) {
      this.savedSelection = selection.getRangeAt(0);
    }
  },

  editLink(e) {
    const button = e.currentTarget;
    const link = button.parentElement.querySelector('a');
    const linkId = Date.now();
    link.dataset.contentBlockEditLinkId = linkId;

    this.savedLinkIdToEdit = linkId

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(link);
    this.currentContentBlockWrapper = contentBlockWrapper;

    this.showEditLinkPopup(link)
  },

  addLink(e) {
    const selection = window.getSelection();

    if (!selection.rangeCount) return;

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(container)
    if (!contentBlockWrapper) return

    const surroundingContentBlock = container.closest(".js-projekt-content-block")

    if (!surroundingContentBlock) {
      return
    }

    this.saveSelection();
    this.currentContentBlockWrapper = contentBlockWrapper;

    this.showEditLinkPopup(range)
  },

  showEditLinkPopup(overElement) {
    const rect = overElement.getBoundingClientRect();

    $(".js-content-block-link-popup").css({
      top: window.scrollY + rect.bottom + "px",
      left: window.scrollX + rect.left + "px",
      display: "block"
    });

    const urlInput = document.querySelector(".js-content-block-link-popup .js-content-block-url-input");

    if (overElement.tagName === "A") {
      urlInput.value = overElement.href

      const blankCheckbox = document.querySelector(".js-content-block-url-black-checkbox")
      blankCheckbox.checked = overElement.target === "_blank";
    }

    urlInput.focus();
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
      a.classList.add("js-content-block-disable-link-click")

      if (blankCheckbox.checked) {
        a.target = "_blank";
      }

      a.appendChild(this.savedSelection.extractContents());
      this.savedSelection.insertNode(a);
    }
    if (this.savedLinkIdToEdit) {
      const link = document.querySelector(`[data-content-block-edit-link-id="${this.savedLinkIdToEdit}"]`)

      link.href = url;

      if (blankCheckbox.checked) {
        link.target = "_blank"
      } else {
        link.removeAttribute("target")
      }
    }

    this.hidePopup()
    this.resetLinkEditState()

    $urlInput.val("");
    blankCheckbox.checked = true;
  },

  cancelLinkEdit() {
    this.hidePopup()
    this.resetLinkEditState()
  },

  hidePopup() {
    $(".js-content-block-link-popup").hide();
  },

  resetLinkEditState() {
    const addLinkButton = this.currentContentBlockWrapper.querySelector(".js-content-block-add-link")
    addLinkButton.disabled = true

    $(".js-content-block-link-popup .js-content-block-url-input").val("")
    $(".js-content-block-url-black-checkbox").prop("checked", true)

    this.savedSelection = null;
    this.currentContentBlockWrapper = null;


    if (this.savedLinkIdToEdit) {
      const currentLinkToEdit = document.querySelector(`[data-content-block-edit-link-id="${this.savedLinkIdToEdit}"]`)
      currentLinkToEdit.removeAttribute("data-content-block-edit-link-id")

      this.savedLinkIdToEdit = null;
    }
  }
}

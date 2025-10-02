ProjektStudio.ContentBlockSimpleEdit.LinkEdit = {
  savedSelection: null,
  currentContentBlockWrapper: null,
  savedLinkIdToEdit: null,
  currentLinkWrapper: null,

  linkClassesToIgnore: [
    "glightbox", "glightbox-disabled", "accordion-title"
  ],

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
    $document.on("click", ".js-content-block-edit-link", this.editLink.bind(this))
  },

  toggleLinkControls(contentBlock, enabled) {
    if (enabled) {
      const ignoreSelector = this.linkClassesToIgnore.map(cls => `:not(.${cls})`).join("")

      contentBlock.querySelectorAll(`a${ignoreSelector}`).forEach((link) => {
        this.wrapLinkWithControls(link)
      })
    }
    else {
      contentBlock
        .querySelectorAll(".js-content-block-link-wrapper")
        .forEach((linkWrapper) => {
          this.removeLinkControls(linkWrapper)
        })
    }
  },

  wrapLinkWithControls(link) {
    if (link.parentElement.classList.contains("js-content-block-link-wrapper")) {
      return
    }

    const linkWrapper = document.createElement("div")
    linkWrapper.classList.add("content-block-link-wrapper", "js-content-block-link-wrapper")

    link.parentNode.insertBefore(linkWrapper, link);
    linkWrapper.appendChild(link);
    linkWrapper.insertAdjacentHTML(
    "beforeend",
      `
      <button type="button" title="Link bearbeiten" class="content-block-edit-link-button js-content-block-edit-link">
          <i class="fas fa-pencil-alt"></i>
        </button>
      `
    );

    return linkWrapper
  },

  removeLinkControls(linkWrapper) {
    const content = linkWrapper.querySelector("a") || linkWrapper.firstChild;

    linkWrapper.parentNode.insertBefore(content, linkWrapper);
    linkWrapper.remove();
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
    this.resetLinkEditState()

    const button = e.currentTarget;
    const link = button.parentElement.querySelector('a');
    const linkId = Date.now();
    link.dataset.contentBlockEditLinkId = linkId;

    this.savedLinkIdToEdit = linkId

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(link);
    this.currentContentBlockWrapper = contentBlockWrapper;

    const linkWrapper = link.closest(".js-content-block-link-wrapper")

    this.currentLinkWrapper = linkWrapper

    this.showEditLinkPopup(linkWrapper)
  },

  addLink(e) {
    this.resetLinkEditState()

    const selection = window.getSelection();
    if (!selection.rangeCount) return;

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = this.getContentBlockAndWrapper(container);
    if (!contentBlockWrapper) return;

    const surroundingContentBlock = container.closest(".js-projekt-content-block");
    if (!surroundingContentBlock) return;

    this.saveSelection();
    this.currentContentBlockWrapper = contentBlockWrapper;

    const linkWrapper = document.createElement("div");
    linkWrapper.className = "-js-draft-link js-content-block-link-wrapper content-block-link-wrapper";
    linkWrapper.appendChild(range.extractContents());
    range.insertNode(linkWrapper);

    this.currentLinkWrapper = linkWrapper
    this.showEditLinkPopup(linkWrapper);
  },

  showEditLinkPopup(linkWrapper) {
    const rect = linkWrapper.getBoundingClientRect();

    linkWrapper.classList.add("-highlight-active")

    $(".js-content-block-link-popup").css({
      top: window.scrollY + rect.bottom + "px",
      left: window.scrollX + rect.left + "px",
      display: "block"
    });

    const urlInput = document.querySelector(".js-content-block-link-popup .js-content-block-url-input");
    const link = linkWrapper.querySelector("a")

    if (link) {
      urlInput.value = link.href

      const blankCheckbox = document.querySelector(".js-content-block-url-black-checkbox")
      blankCheckbox.checked = link.target === "_blank";
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

      const html = this.currentLinkWrapper.innerHTML;

      a.insertAdjacentHTML("beforeend", html);

      this.currentLinkWrapper.parentNode.insertBefore(a, this.currentLinkWrapper);
      this.currentLinkWrapper.remove()
      this.currentLinkWrapper = this.wrapLinkWithControls(a)
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
    if (this.currentLinkWrapper && this.currentLinkWrapper.classList.contains("-js-draft-link")) {
      this.removeLinkControls(this.currentLinkWrapper)
    }
    this.hidePopup()
    this.resetLinkEditState()
  },

  hidePopup() {
    $(".js-content-block-link-popup").hide();
  },

  resetLinkEditState() {
    if (this.currentContentBlockWrapper) {
      const addLinkButton = this.currentContentBlockWrapper.querySelector(".js-content-block-add-link")
      addLinkButton.disabled = true
    }

    if (this.currentLinkWrapper) {
      this.currentLinkWrapper.classList.remove("-highlight-active")
      this.currentLinkWrapper = null;
    }

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

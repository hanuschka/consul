App.Studio.ContentBlocks.SimpleEditMode.LinkEdit = {
  savedSelection: null,
  currentContentBlockWrapper: null,
  savedLinkIdToEdit: null,
  currentLinkWrapper: null,

  linkClassesToIgnore: [
    "glightbox", "glightbox-disabled", "accordion-title"
  ],

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-content-block-add-link", this.addLink.bind(this));
    $document.on("click", ".js-content-block-insert-file-link", this.openFileManagerForLink.bind(this));
    $document.on("click", ".js-content-block-link-popup-pick-file", this.openFileManagerFromPopup.bind(this));
    $document.on("selectionchange", this.handleTextSelectionChange.bind(this))
    $document.on("click", ".js-content-block-accept-link-edit", this.acceptLinkEdit.bind(this));
    $document.on("click", ".js-content-block-cancel-link-edit", this.cancelLinkEdit.bind(this));
    $document.on("click", ".js-content-block-edit-link", this.editLink.bind(this));
    $document.on("click", ".js-content-block-delete-link", this.deleteLink.bind(this));
  },

  toggleLinkControls(contentBlock, enabled) {
    if (enabled) {
      const ignoreSelector = this.linkClassesToIgnore.map(cls => `:not(.${cls})`).join("")

      contentBlock.querySelectorAll(`a${ignoreSelector}`).forEach((link) => {
        this.wrapLinkWithControls(link)
      })
    }
    else {
      this.hidePopup()

      contentBlock
        .querySelectorAll(".js-content-block-link-wrapper")
        .forEach((linkWrapper) => {
          this.removeLinkControls(linkWrapper)
        })
    }
  },

  wrapLinkWithControls(link) {
    if (link.closest(".js-content-block-element-not-editable")) {
      return
    }

    if (link.parentElement.classList.contains("js-content-block-link-wrapper")) {
      return
    }

    const linkWrapper = this.buildLinkWrapper()

    if (this.isOnlyChildAndNotInline(link)) {
      linkWrapper.style.width = "100%";
      linkWrapper.style.justifyContent = link.parentElement.style.justifyContent;
    }

    // TODO: try to use jquery "wrap" method
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

  buildLinkWrapper() {
    const linkWrapper = document.createElement("div")
    linkWrapper.classList.add("content-block-link-wrapper", "js-content-block-link-wrapper")
    linkWrapper.contentEditable = false;

    return linkWrapper
  },

  isOnlyChildAndNotInline(link) {
    if (link.parentNode.children.length !== 1) {
      return false;
    }

    const computedStyle = window.getComputedStyle(link);
    return computedStyle.display !== 'inline';
  },

  removeLinkControls(linkWrapper) {
    const link = linkWrapper.querySelector("a");

    if (link) {
      linkWrapper.parentNode.insertBefore(link, linkWrapper);
    } else if (linkWrapper.classList.contains("-js-draft-link")) {
      const linkContentElement = linkWrapper.querySelector(".js-link-wrapper-content");
      if (linkContentElement) {
        const childNodes = Array.from(linkContentElement.childNodes);
        childNodes.forEach(child => {
          linkWrapper.parentNode.insertBefore(child, linkWrapper);
        });
      }
    }

    linkWrapper.remove();
  },

  // restoreSelection() {
  //   if (this.savedSelection) {
  //     const selection = window.getSelection();
  //     selection.removeAllRanges();
  //     selection.addRange(this.savedSelection);
  //   }
  // },

  handleTextSelectionChange() {
    const selection = window.getSelection();

    if (!selection.rangeCount) {
      return;
    }

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(container)
    if (!contentBlockWrapper) return

    const button = contentBlockWrapper.querySelector(".js-content-block-add-link")
    const insertFileLinkButton = contentBlockWrapper.querySelector(".js-content-block-insert-file-link")
    const hasText = selection.toString().trim().length > 0;

    const surroundingContentBlock = container.closest(".js-content-block")

    if (!surroundingContentBlock) {
      if (button) {
        button.disabled = true
      }

      if (insertFileLinkButton) {
        insertFileLinkButton.disabled = true
      }

      return
    }

    $(".js-content-block-add-link").prop("disabled", true);
    $(".js-content-block-insert-file-link").prop("disabled", true);

    if (contentBlockWrapper) {
      button.disabled = !hasText

      if (insertFileLinkButton) {
        insertFileLinkButton.disabled = !hasText
      }
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
    const link = button.closest(".js-content-block-link-wrapper").querySelector('a');
    const linkId = Date.now();
    link.dataset.contentBlockEditLinkId = linkId;

    this.savedLinkIdToEdit = linkId

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(link);
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

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(container);
    if (!contentBlockWrapper) return;

    const surroundingContentBlock = container.closest(".js-content-block");
    if (!surroundingContentBlock) return;

    this.saveSelection();
    this.currentContentBlockWrapper = contentBlockWrapper;

    const linkWrapper = this.buildLinkWrapper()
    linkWrapper.classList.add("-js-draft-link")

    const linkContentElement = document.createElement("span")
    linkContentElement.classList.add("js-link-wrapper-content")
    linkContentElement.appendChild(range.extractContents())
    linkWrapper.appendChild(linkContentElement)

    range.insertNode(linkWrapper);

    this.currentLinkWrapper = linkWrapper
    this.showEditLinkPopup(linkWrapper);
  },

  openFileManagerForLink(e) {
    this.resetLinkEditState();

    const selection = window.getSelection();
    if (!selection.rangeCount) return;

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer.nodeType === 1
      ? range.commonAncestorContainer
      : range.commonAncestorContainer.parentNode;

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(container);
    if (!contentBlockWrapper) return;

    const surroundingContentBlock = container.closest(".js-content-block");
    if (!surroundingContentBlock) return;

    this.saveSelection();
    this.currentContentBlockWrapper = contentBlockWrapper;

    const linkWrapper = this.buildLinkWrapper();
    linkWrapper.classList.add("-js-draft-link");

    const linkContentElement = document.createElement("span");
    linkContentElement.classList.add("js-link-wrapper-content");
    linkContentElement.appendChild(range.extractContents());
    linkWrapper.appendChild(linkContentElement);
    range.insertNode(linkWrapper);

    this.currentLinkWrapper = linkWrapper;

    App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog.openForDocuments(
      (selectedFile) => {
        this.createNewLinkWithWrapper(
          this.currentLinkWrapper,
          selectedFile.url,
          true,
          selectedFile.content_type
        );
        this.resetLinkEditState();
      },
      null,
      null,
      this.handleFileManagerCancel.bind(this)
    );
  },

  openFileManagerFromPopup() {
    App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog.openForDocuments(
      (selectedFile) => {
        $(".js-content-block-link-popup .js-content-block-url-input").val(selectedFile.url);
        $(".js-content-block-url-black-checkbox").prop("checked", true);
      }
    );
  },

  handleFileManagerCancel() {
    if (this.currentLinkWrapper && this.currentLinkWrapper.classList.contains("-js-draft-link")) {
      this.removeLinkControls(this.currentLinkWrapper);
    }
    this.resetLinkEditState();
  },

  showEditLinkPopup(linkWrapper) {
    // window.getSelection().removeAllRanges();
    linkWrapper.classList.add("-highlight-active")

    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show(
      $(".js-content-block-link-popup"), linkWrapper
    );

    const textInput = document.querySelector(".js-content-block-link-popup .js-content-block-text-input");
    const urlInput = document.querySelector(".js-content-block-link-popup .js-content-block-url-input");
    const link = linkWrapper.querySelector("a")
    console.log("linkWrapper", linkWrapper)
    console.log("a", link)
    const $deleteButton = $(".js-content-block-delete-link")

    if (link) {
      const linkStyle = getComputedStyle(link)
      const isInlineLink = linkStyle.display === "inline" || linkStyle.display === "inline-flex"

      if (App.Studio.utils.hasNoBlockChildren(link)) {
        $(textInput.parentElement).show()
        textInput.value = link.innerHTML.trim()
      }

      // if (isInlineLink && App.Studio.utils.hasNoBlockChildren(link)) {
      if (link.classList.contains("js-content-block-inline-link")) {
        $deleteButton.show()
      }
      else {
        $deleteButton.hide()
      }
    } else {
      $deleteButton.hide()
    }

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

    if (this.savedSelection) {
      this.currentLinkWrapper = this.createNewLinkWithWrapper(this.currentLinkWrapper, url, blankCheckbox.checked)
    }
    else if (this.savedLinkIdToEdit) {
      const link = document.querySelector(`[data-content-block-edit-link-id="${this.savedLinkIdToEdit}"]`)

      link.href = url;

      if (blankCheckbox.checked) {
        link.target = "_blank"
      } else {
        link.removeAttribute("target")
      }

      const textInput = document.querySelector(".js-content-block-link-popup .js-content-block-text-input");
      // const linkStyle = getComputedStyle(link)
      // const isInlineLink = linkStyle.display === "inline" || linkStyle.display === "inline-flex"

      if (link && App.Studio.utils.hasNoBlockChildren(link)) {
        link.innerHTML =
          App.Studio.utils.sanitizeHtml(
          textInput.value,
          {
            allowedTags: ['b','strong','i','span', "u"],
            allowedAttributes: ["class", "style"]
          }
        )
      }
    }

    // this.restoreSelection();
    this.hidePopup()
    this.resetLinkEditState()

    $urlInput.val("");
    blankCheckbox.checked = true;
  },

  createNewLinkWithWrapper(linkWrapper, url, targetBlank = true, contentType = null) {
    const a = document.createElement("a");
    a.href = url;
    a.classList.add("js-content-block-disable-link-click", "js-content-block-inline-link")

    if (targetBlank) {
      a.target = "_blank";
    }

    if (contentType) {
      this.prependFileTypeIcon(a, contentType);
    }

    const html = this.currentLinkWrapper.querySelector(".js-link-wrapper-content").innerHTML;
    a.insertAdjacentHTML("beforeend", html);

    linkWrapper.parentNode.insertBefore(a, linkWrapper);
    linkWrapper.remove()

    return this.wrapLinkWithControls(a)
  },

  prependFileTypeIcon(linkEl, contentType) {
    const iconClass = App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog.getFileTypeIcon(contentType);

    const icon = document.createElement("i");
    icon.className = `fa ${iconClass} content-block-link-file-icon`;

    linkEl.appendChild(icon);
    linkEl.appendChild(document.createTextNode(" "));
  },

  cancelLinkEdit() {
    // this.restoreSelection();

    if (this.currentLinkWrapper && this.currentLinkWrapper.classList.contains("-js-draft-link")) {
      this.removeLinkControls(this.currentLinkWrapper)
    }
    this.hidePopup()
    this.resetLinkEditState()
  },

  deleteLink() {
    const link = this.currentLinkWrapper.querySelector('a')
    const linkContent = link.innerHTML;

    if (!confirm("Möchten Sie diesen Link wirklich entfernen?")) {
      return;
    }

    this.currentLinkWrapper.insertAdjacentHTML('beforebegin', linkContent);
    this.currentLinkWrapper.remove();
    this.hidePopup()
    this.resetLinkEditState()
  },

  hidePopup() {
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.hide($(".js-content-block-link-popup"));
  },

  resetLinkEditState() {
    if (this.currentContentBlockWrapper) {
      const addLinkButton = this.currentContentBlockWrapper.querySelector(".js-content-block-add-link")
      addLinkButton.disabled = true

      const insertFileLinkButton = this.currentContentBlockWrapper.querySelector(".js-content-block-insert-file-link")
      if (insertFileLinkButton) {
        insertFileLinkButton.disabled = true
      }
    }

    $(".js-content-block-link-popup .js-content-block-text-input")
      .val("")
      .parent()
      .hide()

    if (this.currentLinkWrapper) {
      this.currentLinkWrapper.classList.remove("-highlight-active")
      this.currentLinkWrapper = null;
    }

    $(".js-content-block-link-popup .js-content-block-url-input").val("")
    $(".js-content-block-url-black-checkbox").prop("checked", true)

    $(".js-content-block-delete-link").hide()

    this.savedSelection = null;
    this.currentContentBlockWrapper = null;

    if (this.savedLinkIdToEdit) {
      const currentLinkToEdit = document.querySelector(`[data-content-block-edit-link-id="${this.savedLinkIdToEdit}"]`)
      if (currentLinkToEdit) {
        delete currentLinkToEdit.dataset.contentBlockEditLinkId;
      }

      this.savedLinkIdToEdit = null;
    }
  }
}

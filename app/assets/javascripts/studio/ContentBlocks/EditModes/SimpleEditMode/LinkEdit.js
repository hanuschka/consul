App.Studio.ContentBlocks.SimpleEditMode.LinkEdit = {
  savedSelection: null,
  currentContentBlockWrapper: null,
  savedLinkIdToEdit: null,
  currentLinkTarget: null,
  hoveredLink: null,
  inputFrameRequest: null,
  linkEditButton: null,
  linkHighlightFrames: [],
  linkEditButtonOffset: 22,

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

    this.handleLayerMouseOver = this.handleLayerMouseOver.bind(this)
    this.handleLayerMouseLeave = this.handleLayerMouseLeave.bind(this)
    this.handleLayerInput = this.handleLayerInput.bind(this)
  },

  toggleLinkControls(contentBlock, enabled) {
    const $layer = $(this.getLinkControlsLayer(contentBlock))

    $layer.off(".studioLinkEdit")

    if (enabled) {
      this.getEditableLinks(contentBlock).forEach((link) => {
        link.contentEditable = false
      })

      $layer.on("mouseover.studioLinkEdit", this.handleLayerMouseOver)
      $layer.on("mouseleave.studioLinkEdit", this.handleLayerMouseLeave)
      $layer.on("input.studioLinkEdit", this.handleLayerInput)
    }
    else {
      this.hidePopup()
      this.resetLinkEditState()
      this.hideLinkHoverControls()

      contentBlock
        .querySelectorAll(".js-content-block-link-wrapper")
        .forEach((linkWrapper) => {
          this.removeLinkControls(linkWrapper)
        })
    }
  },

  getEditableLinks(contentBlock) {
    return Array.from(contentBlock.querySelectorAll("a"))
      .filter((link) => this.isEditableLink(link))
  },

  isEditableLink(link) {
    const isIgnored = this.linkClassesToIgnore.some((cls) => link.classList.contains(cls))

    return !isIgnored &&
      !link.closest(".js-content-block-element-not-editable") &&
      !link.closest(".js-content-block-link-wrapper")
  },

  getLinkControlsLayer(element) {
    return element.closest(".custom-content-block-wrapper--inner")
  },

  handleLayerMouseOver(e) {
    if (e.target.closest(".js-content-block-edit-link")) return

    const link = e.target.closest("a")
    const isLinkInBody = link && e.currentTarget.contains(link) && link.closest(".js-content-block")

    if (link && link === this.hoveredLink) return

    if (isLinkInBody && this.isEditableLink(link)) {
      this.showLinkHoverControls(link)
      return
    }

    if (!this.hoveredLink) return

    this.hideLinkHoverControls()
  },

  handleLayerMouseLeave() {
    this.hideLinkHoverControls()
  },

  handleLayerInput() {
    if (this.inputFrameRequest) return

    this.inputFrameRequest = requestAnimationFrame(() => {
      this.inputFrameRequest = null
      this.repositionAfterInput()
    })
  },

  repositionAfterInput() {
    if (this.hoveredLink && !this.hoveredLink.isConnected) {
      this.hideLinkHoverControls()
      return
    }

    if (this.hoveredLink) {
      this.positionLinkEditButton()
    }

    this.refreshLinkHighlight()
  },

  showLinkHoverControls(link) {
    const layer = this.getLinkControlsLayer(link)
    const editButton = this.getLinkEditButton()

    this.hoveredLink = link

    if (editButton.parentNode !== layer) {
      layer.appendChild(editButton)
    }

    this.positionLinkEditButton()
    this.refreshLinkHighlight()
  },

  hideLinkHoverControls() {
    this.hoveredLink = null

    if (this.linkEditButton) {
      this.linkEditButton.remove()
    }

    this.refreshLinkHighlight()
  },

  positionLinkEditButton() {
    const layer = this.getLinkControlsLayer(this.hoveredLink)
    const layerRect = layer.getBoundingClientRect()
    const linkRects = Array.from(this.hoveredLink.getClientRects())
    const fallbackRect = this.hoveredLink.getBoundingClientRect()
    const firstRect = linkRects[0] || fallbackRect
    const lastRect = linkRects[linkRects.length - 1] || fallbackRect
    const editButton = this.linkEditButton
    const buttonHeight = editButton.offsetHeight
    const halfButtonWidth = editButton.offsetWidth / 2
    const linkCenter = firstRect.left - layerRect.left + firstRect.width / 2
    const center = App.Studio.utils.clampCenterInside(linkCenter, halfButtonWidth, layerRect.width)
    let top = firstRect.top - layerRect.top - this.linkEditButtonOffset

    const aboveBox = {
      left: layerRect.left + center - halfButtonWidth,
      right: layerRect.left + center + halfButtonWidth,
      top: layerRect.top + top,
      bottom: layerRect.top + top + buttonHeight
    }

    if (this.coversBlockControls(layer, aboveBox)) {
      top = lastRect.bottom - layerRect.top - (buttonHeight - this.linkEditButtonOffset)
    }

    editButton.style.left = `${center}px`
    editButton.style.top = `${top}px`
  },

  coversBlockControls(layer, box) {
    const controls = layer.querySelectorAll(".js-content-block--add-item, .js-content-block-toolbar")

    return Array.from(controls).some((control) => {
      const rect = control.getBoundingClientRect()

      return rect.width > 0 && App.Studio.utils.boxesOverlap(rect, box)
    })
  },

  refreshLinkHighlight() {
    const editedTarget = this.getEditedLinkTarget()
    const target = editedTarget || this.hoveredLink

    if (!target) {
      this.renderLinkHighlightFrames(null, [])
      return
    }

    this.renderLinkHighlightFrames(this.getLinkControlsLayer(target), Array.from(target.getClientRects()))
    this.linkHighlightFrames.forEach((frame) => frame.classList.toggle("-active", Boolean(editedTarget)))
  },

  getEditedLinkTarget() {
    const target = this.currentLinkTarget

    if (target && target.isConnected) return target

    return null
  },

  getActiveLink() {
    const target = this.getEditedLinkTarget()

    if (target && target.matches("a")) return target

    return null
  },

  renderLinkHighlightFrames(layer, linkRects) {
    const layerRect = layer ? layer.getBoundingClientRect() : null

    while (this.linkHighlightFrames.length < linkRects.length) {
      this.linkHighlightFrames.push(this.buildLinkHighlightFrame())
    }

    this.linkHighlightFrames.forEach((frame, index) => {
      const rect = linkRects[index]

      if (!rect) {
        frame.remove()
        return
      }

      if (frame.parentNode !== layer) {
        layer.appendChild(frame)
      }

      frame.style.left = `${rect.left - layerRect.left}px`
      frame.style.top = `${rect.top - layerRect.top}px`
      frame.style.width = `${rect.width}px`
      frame.style.height = `${rect.height}px`
    })
  },

  getLinkEditButton() {
    if (!this.linkEditButton) {
      this.linkEditButton = App.Studio.utils.htmlToSingleDomElement(`
        <button
          type="button"
          title="Link bearbeiten"
          aria-label="Link bearbeiten"
          class="studio-content-block-link-edit-button js-content-block-edit-link js-studio-hide-on-preview"
        >
          <i class="fas fa-pencil-alt" aria-hidden="true"></i>
        </button>
      `)
    }

    return this.linkEditButton
  },

  buildLinkHighlightFrame() {
    const frame = document.createElement("div")
    frame.className = "studio-content-block-link-highlight"

    return frame
  },

  wrapRangeInDraftLink(range) {
    const linkWrapper = document.createElement("span")
    linkWrapper.classList.add("js-content-block-link-wrapper", "-js-draft-link")
    linkWrapper.contentEditable = false

    const linkContentElement = document.createElement("span")
    linkContentElement.classList.add("js-link-wrapper-content")
    linkContentElement.appendChild(range.extractContents())
    linkWrapper.appendChild(linkContentElement)

    range.insertNode(linkWrapper)

    return linkWrapper
  },

  removeLinkControls(linkWrapper) {
    const linkContentElement = linkWrapper.querySelector(".js-link-wrapper-content");
    const link = linkWrapper.querySelector("a")

    if (linkContentElement) {
      const childNodes = Array.from(linkContentElement.childNodes);
      childNodes.forEach(child => {
        linkWrapper.parentNode.insertBefore(child, linkWrapper);
      });
    }
    else if (link) {
      linkWrapper.parentNode.insertBefore(link, linkWrapper)
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

  editLink() {
    const link = this.hoveredLink

    if (!link || !link.isConnected) return

    this.resetLinkEditState()

    const linkId = Date.now();
    link.dataset.contentBlockEditLinkId = linkId;

    this.savedLinkIdToEdit = linkId

    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(link);
    this.currentContentBlockWrapper = contentBlockWrapper;
    this.currentLinkTarget = link

    this.showEditLinkPopup(link)
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

    const linkWrapper = this.wrapRangeInDraftLink(range)

    this.currentLinkTarget = linkWrapper
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
    this.currentLinkTarget = this.wrapRangeInDraftLink(range);

    App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog.openForDocuments(
      (selectedFile) => {
        this.createLinkFromDraft(
          this.currentLinkTarget,
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
    if (this.isDraftLinkTarget()) {
      this.removeLinkControls(this.currentLinkTarget);
    }
    this.resetLinkEditState();
  },

  isDraftLinkTarget() {
    return Boolean(this.currentLinkTarget) && this.currentLinkTarget.classList.contains("-js-draft-link")
  },

  showEditLinkPopup(target) {
    // window.getSelection().removeAllRanges();
    this.refreshLinkHighlight()

    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show(
      $(".js-content-block-link-popup"),
      target,
      "below",
      () => this.cancelLinkEdit()
    );

    const textInput = document.querySelector(".js-content-block-link-popup .js-content-block-text-input");
    const urlInput = document.querySelector(".js-content-block-link-popup .js-content-block-url-input");
    const link = target.matches("a") ? target : target.querySelector("a")
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
      urlInput.value = link.getAttribute("href") || ""

      const blankCheckbox = document.querySelector(".js-content-block-url-black-checkbox")
      blankCheckbox.checked = link.target === "_blank";
    }

    urlInput.focus();
  },

  acceptLinkEdit() {
    const $urlInput = $(".js-content-block-url-input")
    const url = this.normalizeLinkUrl($urlInput.val());
    if (!url) {
      alert("Bitte geben Sie eine URL ein");
      return;
    }
    const blankCheckbox = document.querySelector(".js-content-block-url-black-checkbox")

    if (this.savedSelection) {
      this.currentLinkTarget = this.createLinkFromDraft(this.currentLinkTarget, url, blankCheckbox.checked)
    }
    else if (this.savedLinkIdToEdit) {
      const link = document.querySelector(`[data-content-block-edit-link-id="${this.savedLinkIdToEdit}"]`)

      link.setAttribute("href", url);

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
            allowedTags: ['b','strong','i','em','span', "u"],
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

  normalizeLinkUrl(url) {
    const value = (url || "").trim();
    const emailAddress = /^[^\s@\/:?#]+@[^\s@\/:?#]+\.[a-z]{2,}$/i;
    const bareWebAddress = /^[^\s\/:?#@]+\.[^\s\/:?#@]+(?:[\/?#].*)?$/i;

    if (emailAddress.test(value)) return `mailto:${value}`;
    if (bareWebAddress.test(value)) return `https://${value}`;

    return value;
  },

  createLinkFromDraft(draftWrapper, url, targetBlank = true, contentType = null) {
    const a = document.createElement("a");
    a.setAttribute("href", this.normalizeLinkUrl(url));
    a.classList.add("js-content-block-disable-link-click", "js-content-block-inline-link")

    if (targetBlank) {
      a.target = "_blank";
    }

    if (contentType) {
      this.prependFileTypeIcon(a, contentType);
    }

    const html = draftWrapper.querySelector(".js-link-wrapper-content").innerHTML;
    a.insertAdjacentHTML("beforeend", html);

    draftWrapper.parentNode.insertBefore(a, draftWrapper);
    draftWrapper.remove()
    a.contentEditable = false

    return a
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

    if (this.isDraftLinkTarget()) {
      this.removeLinkControls(this.currentLinkTarget)
    }
    this.hidePopup()
    this.resetLinkEditState()
  },

  deleteLink() {
    const link = this.getActiveLink()

    if (!link) return
    if (!confirm("Möchten Sie diesen Link wirklich entfernen?")) return

    link.insertAdjacentHTML('beforebegin', link.innerHTML);
    link.remove();
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

    this.currentLinkTarget = null;

    this.refreshLinkHighlight()

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

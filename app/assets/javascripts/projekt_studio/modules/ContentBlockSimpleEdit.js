ProjektStudio.ContentBlockSimpleEdit = {
  initialized: false,
  listControlClass: "js-content-block--list-control",
  contentBlocksState: {},

  initialize() {
    this.initEventListeners()
    this.getContentBlockAndWrapper = ProjektStudio.ContentBlocks.getContentBlockAndWrapper.bind(ProjektStudio.ContentBlocks)
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-edit-text-projekt-content-block", this.enterSimpleEditMode.bind(this));

    $document.on("click", ".js-save-edit-text-projekt-content-block", this.saveContentBlockFromSimpleMode.bind(this));
    $document.on("click", ".js-projekt-content-block--text-edit-cancel", this.cancelSimpleEditMode.bind(this));
    $document.on("click", ".js-content-block-disable-link-click", this.disableLinkClick.bind(this));
    // $document.on("keydown", ".projekt-content-block", this.handleSaveContentBlockEditedTextShortcut.bind(this));
  },

  enterSimpleEditMode(e) {
    const { contentBlockWrapper, contentBlock } = this.getContentBlockAndWrapper(e.target)

    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-simple-edit-mode")
    const $accordion = $(contentBlock).find('.accordion a');
    $accordion.off("keydown")

    ProjektStudio.ContentBlocks.storePreviousVersionOfContentBlock(
      contentBlock, contentBlockWrapper
    )
    this.toggleSimpleEditModeFor(contentBlock, true)
  },

  handleSaveContentBlockEditedTextShortcut(e) {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      this.saveContentBlockFromSimpleMode(e);
    }
  },

  saveContentBlockFromSimpleMode(e) {
    const { contentBlockWrapper, contentBlock} = this.getContentBlockAndWrapper(e.target);

    if (contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      contentBlockWrapper.classList.remove("-simple-edit-mode")
        this.toggleSimpleEditModeFor(contentBlock, false, () => {
          const content =
            contentBlock
            .innerHTML
            .trim()
            .replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');

          ProjektStudio.ContentBlocks.updateContentBlock(
            contentBlock,
            contentBlockWrapper.dataset.contentBlockId,
            content,
            true
          )
      });
    }
  },

  cancelSimpleEditMode(e) {
    const { contentBlockWrapper, contentBlock} = this.getContentBlockAndWrapper(e.target);

    contentBlockWrapper.classList.remove("-simple-edit-mode")
    contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;

    this.toggleSimpleEditModeFor(contentBlock, false);
  },

  toggleSimpleEditModeFor(contentBlock, enabled, endCallback) {
    this.toggleContentEditableFor(contentBlock, enabled)

    setTimeout(() => {
      this.toggleLinksInteration(contentBlock, enabled)

      ProjektStudio.ContentBlockSimpleEdit.ListEdit.toggleListControls(
        contentBlock, enabled
      )
      ProjektStudio.ContentBlockSimpleEdit.ImageEdit.toggleImageControls(
        contentBlock, enabled
      )
      ProjektStudio.ContentBlockSimpleEdit.LinkEdit.toggleLinkControls(
        contentBlock, enabled
      )
      // Should be always last item
      this.toggleGlighboxGallery(contentBlock, enabled)
      if (!enabled) {
        $(contentBlock).foundation();
      }

      if (endCallback) {
        endCallback()
      }
    }, 10)
  },

  toggleGlighboxGallery(contentBlock, enabled) {
    const $contentBlock = $(contentBlock);

    if (enabled) {
      contentBlock.querySelectorAll("a.glightbox").forEach((a) => {
        a.outerHTML = a.outerHTML
      })

      $contentBlock.find("a.glightbox").addClass("glightbox-disabled")
      $contentBlock.find("a.glightbox").removeClass("glightbox")
    } else {
      $contentBlock.find("a.glightbox-disabled").addClass("glightbox")
      $contentBlock.find("a.glightbox-disabled").removeClass("glightbox-disabled")

      setTimeout(() => {
        App.ImageGallery.initialize();
      }, 0)
    }
  },

  toggleLinksInteration(contentBlock, state) {
    $(contentBlock).find("a").toggleClass("js-content-block-disable-link-click", state)
  },

  // TODO: Make first element foused
  toggleContentEditableFor(contentBlock, contentEditable) {
    const elements = Array.from(
      contentBlock.querySelectorAll("div, h2, h3, h4, h5, p, figcaption, ol, .js-text-editable, a.accordion-title div")
    );

    let firstEditableElement = null;

    elements.forEach((element) => {
      if (ProjektStudio.utils.hasNoBlockChildren(element)) {
        if (contentEditable) {
          element.contentEditable = true;
          if (!firstEditableElement) {
            firstEditableElement = element;
          }
        } else {
          element.removeAttribute("contenteditable");
        }
      } else {
        element.removeAttribute("contenteditable");
      }
    });

    // Focus the first editable element, if enabling edit mode
    if (contentEditable && firstEditableElement) {
      ProjektStudio.utils.focusContentEditableElement(firstEditableElement)
    }
  },

  toggleLockSaveCancel(contentBlockWrapper, locked) {
    contentBlockWrapper
      .querySelectorAll('.js-simple-edit-mode-controlls button')
      .forEach((button) => {
        button.disabled = locked
      })
  },

  disableLinkClick(e) {
    e.preventDefault()
  }
}

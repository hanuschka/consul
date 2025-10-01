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
    $accordion = $(contentBlock).find('.accordion a');
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
      this.toggleLinksClickModeFor(contentBlock, enabled)
      ProjektStudio.ContentBlockSimpleEdit.ListEdit.toggleListControls(
        contentBlock,
        enabled
      )
      ProjektStudio.ContentBlockSimpleEdit.ImageEdit.toggleImageControls(
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

  toggleLinksClickModeFor(contentBlock, state) {
    $(contentBlock).find("a").toggleClass("js-content-block-disable-link-click", state)
  },

  toggleContentEditableFor(contentBlock, contentEditable) {
    const elements = Array.from(
      contentBlock.querySelectorAll("h2, h3, h4, p,  ol, .js-text-editable")
    );

    const hasBlockChildren = (element) => {
      const blockSelectors = [
        "div", "p", "ul", "ol", "li", "section", "article", "header", "footer", "aside", "nav",
        "h1","h2","h3","h4","h5","h6", "blockquote", "pre"
      ];
      return element.querySelector(blockSelectors.join(", ")) !== null;
    };

    elements.forEach((element) => {
      if (!hasBlockChildren(element)) {
        if (contentEditable) {
          element.contentEditable = true;
          ProjektStudio.utils.focusContentEditableElement(contentBlock);
        } else {
          element.removeAttribute("contenteditable");
        }
      } else {
        element.removeAttribute("contenteditable");
      }
    });
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

ProjektStudio.ContentBlock.SimpleEditMode = {
  initialized: false,
  listControlClass: "js-content-block--list-control",
  contentBlocksState: {},

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-edit-text-projekt-content-block", this.enterSimpleEditMode.bind(this));

    $document.on("click", ".js-save-edit-text-projekt-content-block", this.saveContentBlockFromSimpleMode.bind(this));
    $document.on("click", ".js-projekt-content-block--text-edit-cancel", this.cancelSimpleEditMode.bind(this));
    $document.on("click", ".js-content-block-enter-ai-edit-mode-from-simple", this.enterAiEditModeFromSimple.bind(this));
    $document.on("click", ".js-content-block-disable-link-click", this.disableLinkClick.bind(this));
    $document.on("input", ".js-content-block-margin-bottom-input", this.handleMarginBottomInput.bind(this));
    // $document.on("keydown", ".projekt-content-block", this.handleSaveContentBlockEditedTextShortcut.bind(this));
  },

  enterSimpleEditMode(e) {
    const { contentBlockWrapper, contentBlock } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target)

    ProjektStudio.ContentBlock.DraftStore.storePreviousVersion(
      contentBlock, contentBlockWrapper
    )

    this.switchToSimpleEditMode(contentBlockWrapper);
  },

  switchToSimpleEditMode(contentBlockWrapper) {
    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);

    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-simple-edit-mode", "-in-edit-mode")
    const $accordionLinks = $(contentBlock).find('.accordion a.accordion-title');
    $accordionLinks.off("keydown")

    this.updateMarginBottomInputState(contentBlockWrapper)
    this.toggleSimpleEditModeFor(contentBlock, true)
  },

  handleSaveContentBlockEditedTextShortcut(e) {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      this.saveContentBlockFromSimpleMode(e);
    }
  },

  saveContentBlockFromSimpleMode(e) {
    const { contentBlockWrapper, contentBlock} = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    if (contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      contentBlockWrapper.classList.remove("-simple-edit-mode", "-in-edit-mode")
      this.toggleSimpleEditModeFor(contentBlock, false, () => {
        const content =
          contentBlock
          .innerHTML
          .trim()
          .replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');

        ProjektStudio.ContentBlock.Crud.updateContentBlock(
          contentBlock,
          content,
          { resetFoundationState: true }
        )
      });
    }
  },

  cancelSimpleEditMode(e) {
    const { contentBlockWrapper, contentBlock} = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    contentBlockWrapper.classList.remove("-simple-edit-mode", "-in-edit-mode")
    ProjektStudio.ContentBlock.DraftStore.restorePreviousVersion(contentBlock);

    this.toggleSimpleEditModeFor(contentBlock, false);
  },

  enterAiEditModeFromSimple(e) {
    const { contentBlockWrapper, contentBlock} = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    // if (!contentBlockWrapper.classList.contains("-simple-edit-mode")) {
    //   return;
    // }
    contentBlockWrapper.classList.remove("-simple-edit-mode");
    this.toggleSimpleEditModeFor(contentBlock, false);

    ProjektStudio.ContentBlock.AiEditMode.switchToAiEditMode(contentBlockWrapper);
  },

  toggleSimpleEditModeFor(contentBlock, enabled, endCallback) {
    this.toggleContentEditableFor(contentBlock, enabled)

    setTimeout(() => {
      this.toggleLinksInteration(contentBlock, enabled)

      ProjektStudio.ContentBlock.SimpleEditMode.ListEdit.toggleListControls(
        contentBlock, enabled
      )
      ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.toggleImageControls(
        contentBlock, enabled
      )
      ProjektStudio.ContentBlock.SimpleEditMode.LinkEdit.toggleLinkControls(
        contentBlock, enabled
      )
      // Should be always last item
      this.toggleGlighboxGallery(contentBlock, enabled)
      if (!enabled) {
        ProjektStudio.ContentBlock.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)
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

      $contentBlock.find("a.glightbox")
        .addClass("glightbox-disabled glightbox-link")
        .removeClass("glightbox")
    } else {
      $contentBlock
        .find("a.glightbox-disabled")
        .addClass("glightbox")
        .removeClass("glightbox-disabled")

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
    const ignoreClasess = ".orbit-controls";
    const elements = Array.from(
      contentBlock.querySelectorAll(`div:not(${ignoreClasess}), h2, h3, h4, h5, p, figcaption, ol, .js-text-editable, a.accordion-title`)
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
  },

  handleMarginBottomInput(e) {
    const input = e.currentTarget;
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(input);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const marginValue = parseInt(input.value) || 0;

    contentBlockWrapper.style.marginBottom = `${marginValue}px`;

    $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}`,
      method: "PATCH",
      data: {
        margin_bottom: marginValue
      }
    })
  },

  updateMarginBottomInputState(contentBlockWrapper) {
    const input = contentBlockWrapper.querySelector(".js-content-block-margin-bottom-input");

    if (input) {
      const marginBottom = contentBlockWrapper.style.marginBottom || '0px';
      const parsedValue = parseInt(marginBottom);
      input.value = isNaN(parsedValue) ? 35 : parsedValue;
    }
  }
}

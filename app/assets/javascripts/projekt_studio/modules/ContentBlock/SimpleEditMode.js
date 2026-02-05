ProjektStudio.ContentBlock.SimpleEditMode = {
  initialized: false,
  listControlClass: "js-content-block--list-control",
  contentBlocksState: {},

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-content-block-enter-ai-edit-mode-from-simple", this.switchToAiEditModeFromSimple.bind(this));
    $document.on("click", ".js-content-block-disable-link-click", this.disableLinkClick.bind(this));
    $document.on("input", ".js-content-block-margin-bottom-input", this.handleMarginBottomInput.bind(this));
    $document.on("selectionchange", this.handleSelectionChange.bind(this));
  },

  switchToSimpleEditMode(contentBlockWrapper) {
    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);

    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-simple-edit-mode", "-in-edit-mode")
    contentBlockWrapper.dataset.editMode = 'simple';

    const $accordionLinks = $(contentBlock).find('.accordion a.accordion-title');
    $accordionLinks.off("keydown")

    this.updateMarginBottomInputState(contentBlockWrapper)
    this.toggleSimpleEditModeFor(contentBlock, true)

    setTimeout(() => {
      ProjektStudio.ContentBlock.SimpleEditMode.HeaderEdit.updateDropdownFromSelection(contentBlockWrapper);
    }, 50);
  },

  exitSimpleEditMode(contentBlockWrapper, restoreContent = false) {
    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);

    contentBlockWrapper.classList.remove("-simple-edit-mode", "-in-edit-mode")
    contentBlockWrapper.dataset.editMode = '';

    if (restoreContent) {
      ProjektStudio.ContentBlock.DraftStore.restorePreviousVersion(contentBlock);
    }

    this.toggleSimpleEditModeFor(contentBlock, false);
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
      contentBlockWrapper.dataset.editMode = '';

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
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
    this.exitSimpleEditMode(contentBlockWrapper, true);
  },

  switchToAiEditModeFromSimple(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    this.exitSimpleEditMode(contentBlockWrapper, false);

    ProjektStudio.ContentBlock.AiEditMode.switchToAiEditMode(contentBlockWrapper);
  },

  toggleSimpleEditModeFor(contentBlock, enabled, endCallback) {
    this.toggleContentEditableFor(contentBlock, enabled)

    setTimeout(() => {
      this.toggleLinksInteration(contentBlock, enabled)
      this.toggleGlighboxGallery(contentBlock, enabled)

      ProjektStudio.ContentBlock.SimpleEditMode.ListEdit.toggleListControls(
        contentBlock, enabled
      )
      ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.toggleImageControls(
        contentBlock, enabled
      )
      ProjektStudio.ContentBlock.SimpleEditMode.LinkEdit.toggleLinkControls(
        contentBlock, enabled
      )
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

  toggleContentEditableFor(contentBlock, contentEditable) {
    if (contentEditable) {
      contentBlock.contentEditable = true;
      // We need some delay to disable contentEditable for elements
      setTimeout(() => {
        const nonEditableElements = contentBlock.querySelectorAll(".js-content-block-element-not-editable");
        nonEditableElements.forEach((element) => {
          element.contentEditable = false;
          Array.from(element.querySelectorAll("*")).forEach((el) => {
            el.contentEditable = false;
          });
        });

        ProjektStudio.utils.focusContentEditableElement(contentBlock);
      }, 30)
    } else {
      contentBlock.contentEditable = false;
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
      input.value = isNaN(parsedValue) ? ProjektStudio.config.defaultMarginBottom : parsedValue;
    }
  },

  handleSelectionChange() {
    const selection = window.getSelection();
    if (!selection.rangeCount) {
      return;
    }

    const range = selection.getRangeAt(0);
    const container = range.commonAncestorContainer;
    const element = container.nodeType === 1 ? container : container.parentNode;

    const contentBlockWrapper = element.closest(".js-projekt-content-block-wrapper");
    if (!contentBlockWrapper || !contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      return;
    }

    ProjektStudio.ContentBlock.SimpleEditMode.HeaderEdit.updateDropdownFromSelection(contentBlockWrapper);
  },

}

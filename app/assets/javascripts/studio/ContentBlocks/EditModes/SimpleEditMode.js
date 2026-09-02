App.Studio.ContentBlocks.SimpleEditMode = {
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
    $document.on("click", ".js-content-block-margin-bottom-decrease", this.handleMarginBottomDecrease.bind(this));
    $document.on("click", ".js-content-block-margin-bottom-increase", this.handleMarginBottomIncrease.bind(this));
    $document.on("selectionchange", this.handleSelectionChange.bind(this));
  },

  switchToSimpleEditMode(contentBlockWrapper) {
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);

    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-simple-edit-mode", "-in-edit-mode")
    contentBlockWrapper.dataset.editMode = 'simple';

    const $accordionLinks = $(contentBlock).find('.accordion a.accordion-title');
    $accordionLinks.off("keydown")

    this.updateMarginBottomInputState(contentBlockWrapper)
    this.toggleSimpleEditModeFor(contentBlock, true)

    setTimeout(() => {
      App.Studio.ContentBlocks.SimpleEditMode.HeaderEdit.updateDropdownFromSelection(contentBlockWrapper);
    }, 50);
  },

  exitSimpleEditMode(contentBlockWrapper, restoreContent = false) {
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);

    contentBlockWrapper.classList.remove("-simple-edit-mode", "-in-edit-mode")
    contentBlockWrapper.dataset.editMode = '';

    if (restoreContent) {
      App.Studio.ContentBlocks.DraftStore.restorePreviousVersion(contentBlock);
    }

    this.toggleSimpleEditModeFor(contentBlock, false);
  },

  handleSaveContentBlockEditedTextShortcut(e) {
    if (e.key === "Enter" && (e.metaKey || e.ctrlKey)) {
      this.saveContentBlockFromSimpleMode(e);
    }
  },

  saveContentBlockFromSimpleMode(e) {
    const { contentBlockWrapper, contentBlock} = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);

    if (contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      contentBlockWrapper.classList.remove("-simple-edit-mode", "-in-edit-mode")
      contentBlockWrapper.dataset.editMode = '';

      this.toggleSimpleEditModeFor(contentBlock, false, () => {
        const content =
          contentBlock
          .innerHTML
          .trim()
          .replace(/(<br\s*\/?>\s*){2,}/gi, '<br>');

        App.Studio.ContentBlocks.Crud.updateContentBlock(
          contentBlock,
          content,
          { resetFoundationState: true }
        )
      });
    }
  },

  cancelSimpleEditMode(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    this.exitSimpleEditMode(contentBlockWrapper, true);
  },

  switchToAiEditModeFromSimple(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);

    this.exitSimpleEditMode(contentBlockWrapper, false);

    App.Studio.ContentBlocks.AiEditMode.switchToAiEditMode(contentBlockWrapper);
  },

  toggleSimpleEditModeFor(contentBlock, enabled, endCallback) {
    this.toggleContentEditableFor(contentBlock, enabled)

    if (enabled) {
      setTimeout(() => {
        this.toggleLinksInteration(contentBlock, enabled)
        this.toggleGlighboxGallery(contentBlock, enabled)

        App.Studio.ContentBlocks.SimpleEditMode.ListEdit.toggleListControls(
          contentBlock, enabled
        )
        App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.toggleImageControls(
          contentBlock, enabled
        )
        App.Studio.ContentBlocks.SimpleEditMode.MapEdit.toggleMapControls(
          contentBlock, enabled
        )
        App.Studio.ContentBlocks.SimpleEditMode.MapSourceEdit.toggleMapControls(
          contentBlock, enabled
        )
        App.Studio.ContentBlocks.SimpleEditMode.LinkEdit.toggleLinkControls(
          contentBlock, enabled
        )

        if (endCallback) {
          endCallback()
        }
      }, 10)
    } else {
      this.toggleLinksInteration(contentBlock, enabled)
      this.toggleGlighboxGallery(contentBlock, enabled)

      App.Studio.ContentBlocks.SimpleEditMode.ListEdit.toggleListControls(
        contentBlock, enabled
      )
      App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.toggleImageControls(
        contentBlock, enabled
      )
      App.Studio.ContentBlocks.SimpleEditMode.MapEdit.toggleMapControls(
        contentBlock, enabled
      )
      App.Studio.ContentBlocks.SimpleEditMode.MapSourceEdit.toggleMapControls(
        contentBlock, enabled
      )
      App.Studio.ContentBlocks.SimpleEditMode.LinkEdit.toggleLinkControls(
        contentBlock, enabled
      )

      App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)

      if (endCallback) {
        endCallback()
      }
    }
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
        const nonEditableElements = this.getNonEditableElements(contentBlock);
        nonEditableElements.forEach((element) => {
          element.contentEditable = false;
          Array.from(element.querySelectorAll("*")).forEach((el) => {
            el.contentEditable = false;
          });
        });

        App.Studio.utils.focusContentEditableElement(contentBlock);
      }, 30)
    } else {
      contentBlock.contentEditable = false;

      contentBlock.querySelectorAll("[contenteditable]").forEach((el) => {
        el.removeAttribute("contenteditable");
      });
    }
  },

  getNonEditableElements(contentBlock) {
    const elements = Array.from(
      contentBlock.querySelectorAll(".js-content-block-element-not-editable, i")
    );
    const singleIconSpans = Array.from(contentBlock.querySelectorAll("span"))
      .filter((span) => this.isSingleIconSpan(span));

    return elements.concat(singleIconSpans);
  },

  isSingleIconSpan(span) {
    return span.children.length === 1 &&
      span.children[0].tagName === "I" &&
      span.textContent.trim() === "";
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
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(input);
    const min = parseInt(input.min);
    let marginValue = parseInt(input.value) || 0;

    if (!isNaN(min)) marginValue = Math.max(marginValue, min);

    input.value = marginValue;
    contentBlockWrapper.style.marginBottom = `${marginValue}px`;

    const updateUrl = App.Studio.ContentBlocks.Crud.getUpdateUrl(contentBlockWrapper);

    App.Ajax.request({
      url: updateUrl,
      method: "PATCH",
      data: {
        margin_bottom: marginValue
      }
    })
  },

  handleMarginBottomDecrease(e) {
    this.stepMarginBottomInput(e.currentTarget, -1);
  },

  handleMarginBottomIncrease(e) {
    this.stepMarginBottomInput(e.currentTarget, 1);
  },

  stepMarginBottomInput(button, direction) {
    const contentBlockWrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(button);
    const input = contentBlockWrapper.querySelector(".js-content-block-margin-bottom-input");
    const step = parseInt(input.step) || 1;
    const min = parseInt(input.min);
    const max = parseInt(input.max);
    const current = parseInt(input.value) || 0;
    let next = current + (direction * step);

    if (!isNaN(min)) next = Math.max(next, min);
    if (!isNaN(max)) next = Math.min(next, max);
    if (next === current) return

    input.value = next;
    input.dispatchEvent(new Event("input", { bubbles: true }));
  },

  updateMarginBottomInputState(contentBlockWrapper) {
    const input = contentBlockWrapper.querySelector(".js-content-block-margin-bottom-input");

    if (input) {
      const marginBottom = contentBlockWrapper.style.marginBottom || '0px';
      const parsedValue = parseInt(marginBottom);
      input.value = isNaN(parsedValue) ? App.Studio.Projekt.getDefaultMarginBottom() : parsedValue;
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

    const contentBlockWrapper = element.closest(".js-content-block-wrapper");
    if (!contentBlockWrapper || !contentBlockWrapper.classList.contains("-simple-edit-mode")) {
      return;
    }

    App.Studio.ContentBlocks.SimpleEditMode.HeaderEdit.updateDropdownFromSelection(contentBlockWrapper);
  },

}

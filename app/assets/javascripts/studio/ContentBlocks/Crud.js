App.Studio.ContentBlocks.Crud = {
  addContentBlockAfter: null,
  addContentBlockAtTop: false,

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-add-new-content-block", this.handleCreateContentBlock.bind(this));
    $document.on("click", ".js-add-blank-content-block", this.handleAddBlankContentBlock.bind(this));
    $document.on("click", ".js-delete-content-block", this.handleDeleteContentBlock.bind(this));
  },

  handleCreateContentBlock(e) {
    const templateSelector = App.Studio.ContentBlocks.TemplateSelector;
    const contentBlockTemplate = this.normalizedTemplateNode(
      e.currentTarget.querySelector(".js-content-block-template-content")
    );

    if (templateSelector.selectionMode === "replace") {
      this.replaceContentBlockWithTemplate(templateSelector.replaceTargetWrapper, contentBlockTemplate);
      return
    }

    this.addContentBlock(this.addContentBlockAfter, contentBlockTemplate)
  },

  handleAddBlankContentBlock(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const directSection = button.closest(".js-show-content-block-templates-section");

    if (directSection) {
      const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(button);
      const isAtTop = directSection.classList.contains("js-add-content-block-at-top");

      App.Studio.ContentBlocks.TemplateSelector.selectionMode = "add";
      App.Studio.ContentBlocks.TemplateSelector.replaceTargetWrapper = null;
      App.Studio.ContentBlocks.TemplateSelector.currentContentBlockId = wrapper ? wrapper.dataset.contentBlockId : null;
      this.addContentBlockAfter = wrapper;
      this.addContentBlockAtTop = isAtTop;
    }

    const templateSelector = App.Studio.ContentBlocks.TemplateSelector;
    const blankTemplate = this.buildEmptyContentBlockNode();

    if (templateSelector.selectionMode === "replace") {
      this.replaceContentBlockWithTemplate(templateSelector.replaceTargetWrapper, blankTemplate);
      return
    }

    this.addContentBlock(this.addContentBlockAfter, blankTemplate)
  },

  buildEmptyContentBlockNode() {
    const node = document.createElement("div");
    node.innerHTML = App.Studio.Projekt.templateFunctions.emptyContentBlockHtml;

    return node;
  },

  // The template preview hydrates its map region in place for display, so the
  // live .js-content-block-template-content node may hold a real map. Return a
  // detached node whose map is reset to the {{projekt_map}} token, so the
  // inserted block persists the canonical placeholder (the editor re-hydrates
  // it for display). Non-map templates pass through unchanged.
  normalizedTemplateNode(templateContentEl) {
    const node = document.createElement("div");
    node.innerHTML = App.Studio.utils.resetMapEmbeds(templateContentEl.innerHTML);

    return node;
  },

  replaceContentBlockWithTemplate(wrapper, contentBlockTemplate) {
    const contentBlock = wrapper.querySelector(".js-content-block");
    const templateHTML = contentBlockTemplate.innerHTML;

    App.Studio.ContentBlocks.TemplateSelector.closeDialog();
    App.Studio.ContentBlocks.TemplateSelector.selectionMode = "add";
    App.Studio.ContentBlocks.TemplateSelector.replaceTargetWrapper = null;

    App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock);

    const updatedContent = App.Studio.utils.htmlToDomElement(templateHTML);
    App.Studio.utils.removeFoundationIds(updatedContent);
    contentBlock.innerHTML = updatedContent.innerHTML;
    App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock);
    App.Studio.ContentBlocks.MapEmbed.hydrateIn(contentBlock);

    App.Studio.ContentBlocks.SimpleEditMode.switchToSimpleEditMode(wrapper);
  },

  handleDeleteContentBlock(e) {
    const contentBlockWrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(e.target);
    this.deleteContentBlock(contentBlockWrapper)
  },

  generateDraftIndex() {
    return Date.now();
  },

  addInitialEmptyContentBlock() {
    const emptyHtml = App.Studio.Projekt.templateFunctions.emptyContentBlockHtml;
    const draftContentBlockIndex = this.generateDraftIndex();

    const newContentBlockHTML =
      App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock(
        emptyHtml,
        { draftContentBlockIndex }
      );

    const newContentBlockContainer = App.Studio.utils.htmlToDomElement(newContentBlockHTML).firstChild;

    $('.js-content-blocks-list').append(newContentBlockContainer)

    this.rerenderContentBlockListControls()

    this.createContentBlock(
      newContentBlockContainer,
      emptyHtml,
      draftContentBlockIndex
    )
  },

  addContentBlock(previousContentBlockWrapper, contentBlockTemplate) {
    const isAtTop = this.addContentBlockAtTop;
    this.addContentBlockAtTop = false;

    const previousContentBlockId = (!isAtTop && previousContentBlockWrapper)
      ? previousContentBlockWrapper.dataset.contentBlockId
      : null;
    const draftContentBlockIndex = this.generateDraftIndex();

    App.Studio.ContentBlocks.TemplateSelector.closeDialog()

    const newContentBlockHTML = App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock(
      contentBlockTemplate.innerHTML,
      { draftContentBlockIndex }
    )

    const newContentBlockContainer = App.Studio.utils.htmlToDomElement(newContentBlockHTML).firstChild;
    App.Studio.utils.removeFoundationIds(newContentBlockContainer);

    App.Studio.ContentBlocks.DomHelpers.moveMarginToWrapper(newContentBlockContainer);

    if (isAtTop) {
      const topSection = document.querySelector(".js-content-blocks-list .js-add-content-block-at-top");

      if (topSection) {
        topSection.after(newContentBlockContainer)
      }
      else {
        $('.js-content-blocks-list').prepend(newContentBlockContainer)
      }
    }
    else if (previousContentBlockWrapper) {
      const isFirstBlock = $(previousContentBlockWrapper).prev(".js-content-block-wrapper").length === 0;
      previousContentBlockWrapper.after(newContentBlockContainer)

      if (!isFirstBlock) {
        $(newContentBlockContainer)
          .find(".js-show-content-block-templates")
          .prop("disabled", true)
      }
    }
    else {
      $('.js-content-blocks-list').append(newContentBlockContainer)
    }

    this.rerenderContentBlockListControls()

    this.createContentBlock(
      newContentBlockContainer,
      contentBlockTemplate.innerHTML,
      draftContentBlockIndex,
      previousContentBlockId
    )
  },

  getContentBlocksList() {
    return document.querySelector(".js-content-blocks-list");
  },

  rerenderContentBlockListControls() {
    const hasNoContentBlocks = $('.js-content-blocks-list .js-content-block-wrapper').length === 0

    if (hasNoContentBlocks) {
      this.addContentBlockAfter = null
    }

    $(".js-content-start-section").toggle(hasNoContentBlocks)
    $(".js-add-content-block-at-top").toggle(!hasNoContentBlocks)
    $(".js-delete-all-content-blocks").toggle(!hasNoContentBlocks)
  },

  createContentBlock(newContentBlockContainer, contentBlockHTML, draftContentBlockIndex, previousContentBlockId = null) {
    App.Studio.ContentBlocks.DomHelpers.applyDefaultMarginIfMissing(newContentBlockContainer)

    App.Studio.ContentBlocks.EmptyHintToggle.refreshAll()

    setTimeout(() => {
      newContentBlockContainer.scrollIntoView({ block: "center" })
      App.Studio.ContentBlocks.DomHelpers.reinitFoundationWidgets($(newContentBlockContainer).find('.custom-content-block'))
      App.ImageGallery.initialize()
      App.Studio.ContentBlocks.MapEmbed.hydrateIn(newContentBlockContainer)
    }, 0)

    App.Ajax.request({
      url: this.getCreateUrl(),
      type: "POST",
      dataType: "json",
      data: {
        previous_content_block_id: previousContentBlockId,
        draft_content_block_index: draftContentBlockIndex,
        html: contentBlockHTML
      }
    }).then((response) => {
      this.setDataForFreshContentBlock({
        previous_content_block_id: previousContentBlockId,
        draft_content_block_index: draftContentBlockIndex,
        content_block_id: response.content_block.id,
        urls: response.content_block.urls
      })
    })
      .catch((response) => {
        if (response.error && response.error.message) {
          alert(`Fehler beim Speichern des Inhaltsblocks: ${response.error.message}`)
        }
        else {
          alert("Fehler beim Speichern des Inhaltsblocks")
        }
      })
  },

  setDataForFreshContentBlock(params) {
    const newContentBlockContainer = document.querySelector(
      `.js-content-block-wrapper[data-draft-index='${params.draft_content_block_index}']`
    )

    newContentBlockContainer.classList.add('-highlight-changed')

    setTimeout(() => {
      newContentBlockContainer.classList.remove('-highlight-changed')
    }, 1700)

    newContentBlockContainer.dataset.contentBlockId = params.content_block_id
    newContentBlockContainer.dataset.draft = false
    newContentBlockContainer.classList.remove('-draft')
    this.applyUrlsToWrapper(newContentBlockContainer, params.urls)
    $(newContentBlockContainer)
      .find(".js-show-content-block-templates, .js-add-blank-content-block")
      .prop("disabled", false)
  },

  applyUrlsToWrapper(contentBlockWrapper, urls) {
    if (!urls) return

    if (urls.update_url) contentBlockWrapper.dataset.updateUrl = urls.update_url
    if (urls.destroy_url) contentBlockWrapper.dataset.destroyUrl = urls.destroy_url
    if (urls.update_position_url) contentBlockWrapper.dataset.updatePositionUrl = urls.update_position_url
    if (urls.ai_url) contentBlockWrapper.dataset.aiUrl = urls.ai_url
  },

  getCreateUrl() {
    const contentBlocksList = this.getContentBlocksList();

    if (contentBlocksList && contentBlocksList.dataset.createUrl) {
      return contentBlocksList.dataset.createUrl;
    }

    const projektId = App.Studio.Projekt.getCurrentProjektId();
    return `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks`;
  },

  getUpdateUrl(contentBlockWrapper) {
    const customUrl = contentBlockWrapper.dataset.updateUrl;
    if (customUrl) return customUrl;

    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    return `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}`;
  },

  getDestroyUrl(contentBlockWrapper) {
    const customUrl = contentBlockWrapper.dataset.destroyUrl;
    if (customUrl) return customUrl;

    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    return `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}`;
  },

  updateContentBlock(contentBlock, newContent, { resetFoundationState = false, saveVersion = true } = {}) {
    const contentBlockWrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(contentBlock);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    // Strip any hydrated map back to the {{projekt_map}} placeholder so the
    // persisted body stays canonical; the live map is re-hydrated below.
    const normalized = App.Studio.utils.resetMapEmbeds(newContent);
    const sanitized = App.Studio.utils.sanitizeAdminHtml(normalized);

    const oldContent = App.Studio.utils.resetMapEmbeds(
      contentBlock.dataset.previousContentBlockHtml
        ? contentBlock.dataset.previousContentBlockHtml
        : contentBlock.innerHTML.trim()
    );

    const updatedContentBlock = App.Studio.utils.htmlToDomElement(sanitized);
    const newContentTrimmed = updatedContentBlock.innerHTML.trim();

    if (resetFoundationState) {
      App.Studio.utils.resetFoundationAccordionStateFor(updatedContentBlock)
    }

    const defaultContent = contentBlockWrapper.dataset.defaultContent;
    const willShowDefault = defaultContent && this.isContentEmpty(newContentTrimmed);

    if (saveVersion && !willShowDefault && oldContent !== newContentTrimmed) {
      App.Studio.ContentBlocks.ChangeHistory.saveVersion(contentBlock, contentBlockWrapper, oldContent);
    }

    App.Ajax.request({
      url: this.getUpdateUrl(contentBlockWrapper),
      type: "PATCH",
      dataType: "json",
      data: {
        html: updatedContentBlock.innerHTML
      }
    })
      .then((response) => {
        this.syncDomFromServer(contentBlock, response);

        if (response && response.stripped) {
          this.showSanitizationNotice();
        }

        if (!willShowDefault) {
          App.Studio.ContentBlocks.DomHelpers.showBlockStatus(contentBlockWrapper, "saved");
        }
      })
      .catch(() => {
        App.Studio.ContentBlocks.DomHelpers.showBlockStatus(contentBlockWrapper, "error");
      })


    // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
    // DO NOT DELETE
    contentBlock.innerHTML = updatedContentBlock.innerHTML;

    if (willShowDefault) {
      contentBlock.innerHTML = defaultContent;
      this.showDefaultContentNotification(contentBlockWrapper);
    }

    App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)

    // Display reset above replaced the live map with the placeholder token;
    // re-hydrate so the editor keeps showing a map after saving.
    App.Studio.ContentBlocks.MapEmbed.hydrateIn(contentBlock)
  },

  syncDomFromServer(contentBlock, response) {
    if (!response || typeof response.body !== "string") return

    const currentContent = contentBlock.innerHTML.trim();
    if (currentContent === response.body.trim()) return

    contentBlock.innerHTML = response.body;
    App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock);
  },

  showSanitizationNotice() {
    alert("Hinweis: Einige unzulässige HTML-Inhalte (Skripte, Event-Handler oder unsichere Links) wurden beim Speichern entfernt.");
  },

  showDefaultContentNotification(wrapper) {
    const toolbar = wrapper.querySelector(".custom-content-block--toolbar");
    let notification = toolbar.querySelector(".js-default-content-notification");

    if (notification) return

    notification = document.createElement("span");
    notification.className = "custom-content-block--default-notification js-default-content-notification";
    notification.textContent = "Standardinhalt wird angezeigt";
    toolbar.prepend(notification);

    setTimeout(() => {
      notification.remove();
    }, 2000);
  },

  isContentEmpty(html) {
    const stripped = html
      .replace(/<br\s*\/?>/gi, "")
      .replace(/<\/?(p|div|span)(\s[^>]*)?>/gi, "")
      .replace(/[\s\u00A0]/g, "");

    return stripped.length === 0;
  },

  deleteContentBlock(contentBlockWrapper) {
    const deleteConfirmed = confirm("Soll dieser Inhaltsblock wirklich gelöscht werden?")

    if (!deleteConfirmed) return

    const destroyUrl = this.getDestroyUrl(contentBlockWrapper)
    const nextContentBlockSection = contentBlockWrapper.nextElementSibling
    const prevContentBlockSection = contentBlockWrapper.previousElementSibling
    const scrollTo = nextContentBlockSection || prevContentBlockSection

    contentBlockWrapper.remove()

    this.rerenderContentBlockListControls()

    if (scrollTo) {
      scrollTo.scrollIntoView({block: "center"})
    }

    App.Ajax.request({
      url: destroyUrl,
      type: "DELETE",
      dataType: "json"
    })
      .catch((response) => {
        if (response.error && response.error.message) {
          alert(`Fehler beim Löschen des Inhaltsblocks: ${response.error.message}`)
        }
        else {
          alert("Fehler beim Löschen des Inhaltsblocks")
        }
      })
  }
};

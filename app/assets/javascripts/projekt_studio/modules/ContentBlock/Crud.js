ProjektStudio.ContentBlock.Crud = {
  addContentBlockAfter: null,

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-add-new-content-block", this.handleCreateContentBlock.bind(this));
    $document.on("click", ".js-delete-projekt-content-block", this.handleDeleteContentBlock.bind(this));
  },

  handleCreateContentBlock(e) {
    const contentBlockTemplate = e.currentTarget.querySelector(".js-content-block-template-content");
    this.addContentBlock(this.addContentBlockAfter, contentBlockTemplate)
  },

  handleDeleteContentBlock(e) {
    const contentBlockWrapper = ProjektStudio.ContentBlock.DomHelpers.getParentContentBlockWrapper(e.target);
    this.deleteContentBlock(contentBlockWrapper)
  },

  generateDraftIndex() {
    return Date.now();
  },

  addInitialEmptyContentBlock() {
    const emptyHtml = ProjektStudio.templateFunctions.emptyContentBlockHtml;
    const draftContentBlockIndex = this.generateDraftIndex();

    const newContentBlockHTML =
      ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
        emptyHtml,
        { draftContentBlockIndex }
      );

    const newContentBlockContainer = ProjektStudio.utils.htmlToDomElement(newContentBlockHTML).firstChild;

    $('.js-content-blocks-list').append(newContentBlockContainer)

    this.rerenderContentBlockListControls()

    this.createContentBlock(
      newContentBlockContainer,
      emptyHtml,
      draftContentBlockIndex
    )
  },

  addContentBlock(previousContentBlockWrapper, contentBlockTemplate) {
    console.log(previousContentBlockWrapper)
    const previousContentBlockId = previousContentBlockWrapper ? previousContentBlockWrapper.dataset.contentBlockId : null;
    const draftContentBlockIndex = this.generateDraftIndex();

    ProjektStudio.ContentBlockTemplateSelector.closeDialog()

    const newContentBlockHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
      contentBlockTemplate.innerHTML,
      { draftContentBlockIndex }
    )

    const newContentBlockContainer = ProjektStudio.utils.htmlToDomElement(newContentBlockHTML).firstChild;

    ProjektStudio.ContentBlock.DomHelpers.moveMarginToWrapper(newContentBlockContainer);

    if (previousContentBlockWrapper) {
      const isFirstBlock = $(previousContentBlockWrapper).prev(".js-projekt-content-block-wrapper").length === 0;
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

  rerenderContentBlockListControls() {
    const hasNoContentBlocks = $('.js-content-blocks-list .js-content-block').length === 0

    if (hasNoContentBlocks) {
      this.addContentBlockAfter = null
    }

    $(".js-projekt-content-start-section").toggle(hasNoContentBlocks)
    $(".js-add-first-content-block-wrapper").toggle(hasNoContentBlocks)
    $(".js-delete-all-content-blocks").toggle(!hasNoContentBlocks)
  },

  createContentBlock(newContentBlockContainer, contentBlockHTML, draftContentBlockIndex, previousContentBlockId = null) {
    setTimeout(() => {
      newContentBlockContainer.scrollIntoView({ block: "center" })
      $(newContentBlockContainer).find('.projekt-content-block').foundation()
      App.ImageGallery.initialize()
    }, 0)

    const projektId = ProjektStudio.getCurrentProjektId()

    $.ajax({
      url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks`,
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
        content_block_id: response.content_block.id
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
      `.js-projekt-content-block-wrapper[data-draft-index='${params.draft_content_block_index}']`
    )

    newContentBlockContainer.classList.add('-highlight-changed')

    setTimeout(() => {
      newContentBlockContainer.classList.remove('-highlight-changed')
    }, 1700)

    newContentBlockContainer.dataset.contentBlockId = params.content_block_id
    newContentBlockContainer.dataset.draft = false
    newContentBlockContainer.classList.remove('-draft')
    $(newContentBlockContainer).find(".js-show-content-block-templates").prop("disabled", false)
  },

  updateContentBlock(contentBlock, newContent, { resetFoundationState = false, saveVersion = true } = {}) {
    const contentBlockWrapper = ProjektStudio.ContentBlock.DomHelpers.getParentContentBlockWrapper(contentBlock);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    const oldContent = contentBlock.dataset.previousContentBlockHtml
      ? contentBlock.dataset.previousContentBlockHtml
      : contentBlock.innerHTML.trim();

    const updatedContentBlock = ProjektStudio.utils.htmlToDomElement(newContent);
    const newContentTrimmed = updatedContentBlock.innerHTML.trim();

    if (resetFoundationState) {
      ProjektStudio.utils.resetFoundationAccordionStateFor(updatedContentBlock)
    }

    if (saveVersion && oldContent !== newContentTrimmed) {
      ProjektStudio.ContentBlock.ChangeHistory.saveVersion(contentBlock, contentBlockWrapper, oldContent);
    }

    $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}`,
      type: "PATCH",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
      data: {
        html: updatedContentBlock.innerHTML
      }
    })
      .catch((response) => {
        if (response.error && response.error.message) {
          alert(`Fehler beim Speichern des Inhaltsblocks: ${response.error.message}`)
        }
        else {
          alert("Fehler beim Speichern des Inhaltsblocks")
        }
      })


    // HACK to make Foundation re-initialization work for accorions and other foundation ui elements
    // DO NOT DELETE
    contentBlock.innerHTML = updatedContentBlock.innerHTML;
    ProjektStudio.ContentBlock.DomHelpers.reinitPluginElementsAndWidgets(contentBlock)

  },

  deleteContentBlock(contentBlockWrapper) {
    const deleteConfirmed = confirm("Soll dieser Inhaltsblock wirklich gelöscht werden?")

    if (!deleteConfirmed) return

    const contentBlockId = contentBlockWrapper.dataset.contentBlockId
    const nextContentBlockSection = contentBlockWrapper.nextElementSibling
    const prevContentBlockSection = contentBlockWrapper.previousElementSibling
    const scrollTo = nextContentBlockSection || prevContentBlockSection

    // Clean up tooltips on content block destroy
    contentBlockWrapper.querySelectorAll("[data-tooltip]").forEach((element) => {
      const instance = $(element).data("zf.tooltip");
      if (instance) instance.destroy();
    })

    contentBlockWrapper.remove()

    this.rerenderContentBlockListControls()

    if (scrollTo) {
      scrollTo.scrollIntoView({block: "center"})
    }

    $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}`,
      type: "DELETE",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
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

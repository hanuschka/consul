ProjektStudio.ContentBlock.Crud = {
  addContentBlockAfter: null,

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-add-new-content-block", this.handleCreateContentBlock.bind(this));
    $document.on("click", ".js-delete-projekt-content-block", this.handleDeleteContentBlock.bind(this));
  },

  handleCreateContentBlock(e) {
    const contentTemplate = e.currentTarget.querySelector(".js-content-block-template-content");
    this.createContentBlock(this.addContentBlockAfter, contentTemplate)
  },

  handleDeleteContentBlock(e) {
    const contentBlockWrapper = ProjektStudio.ContentBlock.DomHelpers.getParentContentBlockWrapper(e.target);
    this.deleteContentBlock(contentBlockWrapper)
  },

  createContentBlock(previousContentBlockWrapper, contentTemplateElement) {
    const previousContentBlockId = previousContentBlockWrapper.dataset.contentBlockId;
    const draftContentBlockIndex = Date.now();

    ProjektStudio.ContentBlockTemplateSelector.closeDialog()

    const newContentBlockHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
      contentTemplateElement.innerHTML, {
        draftContentBlockIndex: draftContentBlockIndex
      }
    )

    const newContentBlock = ProjektStudio.utils.htmlToDomElement(newContentBlockHTML).firstChild;
    newContentBlock.dataset.draft = true;
    newContentBlock.classList.add('-draft')

    ProjektStudio.ContentBlock.DomHelpers.moveMarginToWrapper(newContentBlock);

    if (previousContentBlockWrapper) {
      if ($(previousContentBlockWrapper).prev(".js-projekt-content-block-wrapper").length === 0) {
        previousContentBlockWrapper.after(newContentBlock)
      }
      else {
        $(previousContentBlockWrapper).after(newContentBlock)
        $(newContentBlock).find(".js-show-content-block-templates").prop("disabled", true)
      }
    }

    $(".js-projekt-content-start-section").hide();

    setTimeout(() => {
      newContentBlock.scrollIntoView({ block: "center" })
      $(newContentBlock).find('.projekt-content-block').foundation();
      App.ImageGallery.initialize();
    }, 0)

    const projektId = ProjektStudio.getCurrentProjektId()

    $.ajax({
      url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks`,
      type: "POST",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
      data: {
        previous_content_block_id: previousContentBlockId,
        draft_content_block_index: draftContentBlockIndex,
        html: contentTemplateElement.innerHTML
      }
    }).then((response) => {
      this.setDataForFreshContentBlock({
        previous_content_block_id: previousContentBlockId,
        enter_ai_mode: false,
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
    const newContentBlock = document.querySelector(
      `.js-projekt-content-block-wrapper[data-draft-index='${params.draft_content_block_index}']`
    )

    newContentBlock.classList.add('-highlight-changed')

    setTimeout(() => {
      newContentBlock.classList.remove('-highlight-changed')
    }, 1700)

    newContentBlock.dataset.contentBlockId = params.content_block_id;
    newContentBlock.dataset.draft = false;
    newContentBlock.classList.remove('-draft')
    $(newContentBlock).find(".js-show-content-block-templates").prop("disabled", false)

    if (ProjektStudio.isEmbedded && params.enter_ai_mode === "true") {
      ProjektStudio.ContentBlock.DtAiEditMode.enterAiEditMode(newContentBlock);
    }
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

    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const nextContentBlockSection = contentBlockWrapper.nextElementSibling;
    const prevContentBlockSection = contentBlockWrapper.previousElementSibling;
    const scrollTo = nextContentBlockSection || prevContentBlockSection;

    contentBlockWrapper.remove()

    if (scrollTo) {
      scrollTo.scrollIntoView({block: "center"});
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

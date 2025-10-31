 ProjektStudio.ContentBlocks = {
  initialized: false,
  aceInstances: {},
  addContentBlockAfter: null,

  initialize() {
    this.initEventListeners()
    this.renderContentBlocks()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-show-content-block-templates", this.openContentBlockTemplateSelector.bind(this));
    $document.on("click", ".js-add-new-content-block", this.createContentBlock.bind(this));
    $document.on("click", ".js-copy-content-block-template", this.copyContentBlockTemplate.bind(this));

    $document.on("click", ".js-projekt-content-block--regenerate", this.handleRegenerateContentBlock.bind(this));
    $document.on("click", ".js-projekt-content-block--ai-edit", this.enterAiEditMode.bind(this));
    $document.on("click", ".js-delete-projekt-content-block", this.deleteContrentBlock.bind(this));

    $document.on("click", ".js-html-edit-content-block", this.enterHtmlEditMode.bind(this));
    $document.on("click", ".js-code-edit-content-block", this.enterCodeEditMode.bind(this));
    $document.on("click", ".js-projekt-content-block--html-edit-cancel", this.cancelHtmlEditMode.bind(this));
    $document.on("click", ".js-projekt-content-block--ai-edit-cancel", this.cancelAiEditMode.bind(this));
    $document.on("click", ".js-save-edit-html-projekt-content-block", this.saveConventBlockFromCkeditor.bind(this));

    $document.on("click", ".js-content-block-reset-to-prev-version", this.resetContentBlockToPreviousVersion.bind(this));

    window.addEventListener('message', this.handleGlobalMessage.bind(this));
  },

  handleGlobalMessage(event) {
    if (event.data) {
      const data = ProjektStudio.utils.parseIframeEventData(event.data);
      const params = data.params

      switch(data.event_type) {
        // case "Consul.ProjektStudioConsul.setContentBlockTemplates":
        //   this.setContentBlockTemplates(params);
        //   break;
        case "Consul.ProjektStudio.updateContentBlockOnUi":
          this.updateContentBlockOnUi(params);
          break;
        case "setDataForFreshContentBlockOnUI":
          this.setDataForFreshContentBlockOnUI(params);
          break;
        case "updateHTML":
          this.morphElementHTML(params.selector, params.html)
          break;
        case "toggleLockContentBlockEdit":
          this.toggleLockContentBlockEdit(params,contentBlockId, params.locked)
          break;
      }
    }
  },

  renderContentBlocks() {
    const projektPageContent =  document.querySelector(".js-custom-page-content--inner");

    if (!projektPageContent) return

    const html = projektPageContent.outerHTML;
    let parser = new DOMParser();
    let doc = parser.parseFromString(html, 'text/html');

    const contentBlocks = Array.from(doc.querySelectorAll('.projekt-content-block'));
    let wrappedContentBlocksHtml = '';

    const projektId = ProjektStudio.getCurrentProjektId()

    if (contentBlocks.length > 0) {
      wrappedContentBlocksHtml = Array.from(contentBlocks).map((contentBlock) => {
        return ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
          contentBlock.innerHTML,
          {
            projektId,
            contentBlockId: contentBlock.dataset.id
          }
        );
      }).join("")
    }
    // else {
    //   wrappedContentBlocksHtml =
    //     ProjektStudio.templateFunctions.initialContentBlockWrapperHtml(
    //       projektId
    //     );
    // }

    const newHtml =
      ProjektStudio.templateFunctions.wrapWithContentBlockListHtml(
        wrappedContentBlocksHtml, projektId
      )

    this.morphElementHTML(".js-custom-page-content--inner", newHtml);
  },

  setContentBlockTemplates(params) {
    const initialTemplatesContainer = document.querySelector(".js-content-block-templates-load-container")

    initialTemplatesContainer.innerHTML = params.templates
  },

  enterAiEditMode(e) {
    this.turnOnAiEditContentBlockMode(this.getParentContentBlockWrapper(e.target))
  },

  handleRegenerateContentBlock(e) {
    this.regenerateContentBlock(this.getParentContentBlockWrapper(e.target), e.currentTarget.dataset.regenerateType)
  },

  regenerateContentBlock(contentBlockWrapper, regenerateType) {
    this.cancelAllContentBlockRegenerateLoadStates();

    contentBlockWrapper.classList.add("-loading");

    // this.toggleLockContentBlockEdit(contentBlockWrapper.dataset.contentBlockId, true)

    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block");
    const contentBlockHTML = contentBlock.innerHTML;

    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockWrapper)

    ProjektStudio.utils.sendMessageToDtParentFrame("regenerateContentBlock", {
      regenerate_type: regenerateType,
      content_block_id: contentBlockWrapper.dataset.contentBlockId,
      html: contentBlockHTML
    })
  },

  turnOnAiEditContentBlockMode(contentBlockWrapper) {
    this.cancelAllContentBlockRegenerateLoadStates();

    contentBlockWrapper.classList.add("-ai-edit-mode");
    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block");
    // TODO
    // this.toggleLockAiFunctions(true);
    // this.toggleLockContentBlockEdit(contentBlockWrapper.dataset.contentBlockId, true)

    ProjektStudio.utils.sendMessageToDtParentFrame("aiEditContentBlock", {
      content_block_id: contentBlockWrapper.dataset.contentBlockId,
      html: contentBlock.innerHTML
    })
  },

  toggleLockContentBlockEdit(contentBlockId, locked) {
    const contentBlockWrapper = document.querySelector(`.js-projekt-content-block-wrapper[data-content-block-id='${contentBlockId}']`)
    const controlls = contentBlockWrapper.querySelector(".js-projekt-content-block-edit-standard-controlls")

    const title = locked ? "Edit is locked while ai process is running" : ""
    controlls.title = title

    const buttons = controlls.querySelectorAll("button")

    buttons.forEach((button) => {
      if (locked) {
        button.dataset.originalTitle = button.title
      }

      const buttonTitle = locked ? "Edit is locked while ai process is running" : button.dataset.originalTitle

      button.disabled = locked
      button.title = buttonTitle
    })
  },

  morphElementHTML(selector, html, afterUpdate = null) {
    const element = document.querySelector(selector);

    element.innerHTML = html;

    setTimeout(() => {
      $(element).foundation();
      this.initSortable();
      App.ImageGallery.initialize();
    }, 10)
  },

  initSortable() {
    setTimeout(() => {
      const element = document.querySelector(".content-blocks-container");

      new Sortable(
        element, {
          handle: ".js-dnd-handle",
          animation: 150,
          ghostClass: 'content-block-dnd-placeholder',
          dragClass: "content-block-dnd-move",
          scrollSensitivity: 2,
          scrollSpeed: 3,
          draggable: ".js-projekt-content-block-wrapper:not(.js-add-first-content-block-wrapper)",
          onUpdate: (e) => { this.moveContentBlock(e) },
        });
    }, 200)
  },

  moveContentBlock(e) {
    const contentBlockId = e.item.dataset.contentBlockId
    // const newPosition = e.newIndex + 1;
    const newPosition = e.newIndex

    $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}/update_position`,
      type: "PATCH",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
      data: {
        position: newPosition
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
  },

  setDataForFreshContentBlockOnUI(params) {
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
      this.turnOnAiEditContentBlockMode(newContentBlock);
    }
  },

  getContentBlockSectionForId(contentBlockId) {
    return document.querySelector(`.js-projekt-content-block-wrapper[data-content-block-id="${contentBlockId}"]`);
  },

  updateContentBlockOnUi(params) {
    // console.log("updateContentBlockOnUi consul", params)
    const contentBlockWrapper = this.getContentBlockSectionForId(params.content_block_id)
    const contentBlock = contentBlockWrapper.querySelector('.projekt-content-block')

    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockWrapper)

    contentBlock.innerHTML = params.html

    $(contentBlock).foundation();
    App.ImageGallery.initialize();

    contentBlockWrapper
      .classList
      .remove('-loading')

    contentBlockWrapper
      .classList
      .remove("-ai-edit-mode")
  },

  getParentContentBlockWrapper(element) {
    return element.closest('.js-projekt-content-block-wrapper');
  },

  deleteContrentBlock(e) {
    const deleteConfirmed = confirm("Soll dieser Inhaltsblock wirklich gelöscht werden?")

    if (!deleteConfirmed) return

    const contentBlockWrapper = this.getParentContentBlockWrapper(e.target);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const nextContentBlockSection = contentBlockWrapper.nextElementSibling;
    const prevContentBlockSection = contentBlockWrapper.previousElementSibling;
    const scrollTo = nextContentBlockSection || prevContentBlockSection;

    contentBlockWrapper.remove()

    // if ($('.js-projekt-content-block-wrapper').length === 0) {
    //   const projektId = ProjektStudio.getCurrentProjektId()
    //   const wrappedContentBlocksHtml = ProjektStudio.templateFunctions.initialContentBlockWrapperHtml(projektId);
    //   const newHtml = ProjektStudio.templateFunctions.wrapWithContentBlockListHtml(wrappedContentBlocksHtml, projektId)

    //   this.morphElementHTML(".js-custom-page-content--inner", newHtml);
    // }

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
  },

  openContentBlockTemplatesDialog() {
    $('#contentBlockTemplatesModal').foundation('open');
  },

  closeContentBlockTemplatesDialog() {
    $('#contentBlockTemplatesModal').foundation('close');
  },

  cancelAllContentBlockRegenerateLoadStates: function() {
    $('.js-projekt-content-block-wrapper.-loading').removeClass('-loading');
    $('.js-projekt-content-block-wrapper.-ai-edit-mode').removeClass('-ai-edit-mode');
  },

  openContentBlockTemplateSelector(e) {
    this.addContentBlockAfter = this.getParentContentBlockWrapper(e.currentTarget);

    this.openContentBlockTemplatesDialog()
  },

  createContentBlock(e) {
    const previousContentBlockWrapper = this.addContentBlockAfter
    const contentTemplate = e.currentTarget.querySelector(".js-content-block-template-content");
    const previousContentBlockId = previousContentBlockWrapper.dataset.contentBlockId;
    const draftContentBlockIndex = Date.now();

    this.closeContentBlockTemplatesDialog()

    const newContentBlockHTML = ProjektStudio.templateFunctions.addStudioControlsToContentBlock(
      contentTemplate.innerHTML, {
        draftContentBlockIndex: draftContentBlockIndex
      }
    )

    const newContentBlock = ProjektStudio.utils.htmlToDomElement(newContentBlockHTML).firstChild;
    newContentBlock.dataset.draft = true;
    newContentBlock.classList.add('-draft')

    if (previousContentBlockWrapper) {
      if ($(previousContentBlockWrapper).prev(".js-projekt-content-block-wrapper").length === 0) {
        previousContentBlockWrapper.after(newContentBlock)
      }
      else {
        $(previousContentBlockWrapper).after(newContentBlock)
        $(newContentBlock).find(".js-show-content-block-templates").prop("disabled", true)
      }
    }

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
        html: contentTemplate.innerHTML
      }
    }).then((response) => {
      this.setDataForFreshContentBlockOnUI({
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

  copyContentBlockTemplate(e) {
    e.stopPropagation();
    e.preventDefault();

    const templateItem = e.currentTarget.closest('.custom-content-template--item');
    const contentTemplate = templateItem.querySelector('.js-content-block-template-content');
    const templateContent = contentTemplate.innerHTML.trim();

    // Copy to clipboard
    if (navigator.clipboard && window.isSecureContext) {
      // Use modern clipboard API
      navigator.clipboard.writeText(templateContent).then(() => {
        this.showCopySuccessFeedback(e.currentTarget);
      }).catch((err) => {
        console.error('Failed to copy: ', err);
        this.fallbackCopyToClipboard(templateContent, e.currentTarget);
      });
    } else {
      // Fallback for older browsers
      this.fallbackCopyToClipboard(templateContent, e.currentTarget);
    }
  },

  fallbackCopyToClipboard(text, button) {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    textArea.style.position = 'fixed';
    textArea.style.left = '-999999px';
    textArea.style.top = '-999999px';
    document.body.appendChild(textArea);
    textArea.focus();
    textArea.select();

    try {
      document.execCommand('copy');
      this.showCopySuccessFeedback(button);
    } catch (err) {
      console.error('Fallback copy failed: ', err);
      alert('Kopieren fehlgeschlagen. Bitte manuell kopieren.');
    } finally {
      document.body.removeChild(textArea);
    }
  },

  showCopySuccessFeedback(button) {
    const originalIcon = button.querySelector('i');
    const originalClass = originalIcon.className;

    // Change icon to checkmark
    originalIcon.className = 'fa fas fa-check';
    button.classList.add("-copied")

    // Reset after 2 seconds
    setTimeout(() => {
      originalIcon.className = originalClass;
      button.classList.remove("-copied")
    }, 300);
  },

  enterHtmlEditMode(e) {
    const { contentBlockWrapper, contentBlock } = this.getContentBlockAndWrapper(e.target)

    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-html-edit-mode")
    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockWrapper)

    contentBlock.innerHTML = `
      <textarea
        name="body"
        id="${this.genTextEditorIdForTextarea(contentBlockWrapper.dataset.contentBlockId)}"
        rows="8"
        class="html-area extended-a"
        style="visibility: hidden; display: none;"
      >
         ${contentBlock.innerHTML}
      </textarea>
    `

    App.HTMLEditor.enableCKeditorFor(contentBlock.querySelector("textarea"))
  },

  enterCodeEditMode(e) {
    const { contentBlockWrapper, contentBlock } = this.getContentBlockAndWrapper(e.target)

    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-code-edit-mode")
    this.storePreviousVersionOfContentBlock(contentBlock, contentBlockWrapper)

    contentBlock.innerHTML = `
      <textarea
        name="body"
        rows="8"
        style="visibility: hidden; display: none;">
         ${contentBlock.innerHTML}
      </textarea>
    `

    const textarea = contentBlockWrapper.querySelector("textarea[name='content']")
    const scopedToContentBlockEditorName = this.getCodeEditorName(contentBlockWrapper)
    let editor = this.aceInstances[scopedToContentBlockEditorName];

    if (!editor) {
      editor = ace.edit(textarea)
      this.aceInstances[scopedToContentBlockEditorName] = editor

      editor.setFontSize(14)
      editor.session.setMode("ace/mode/html");

      // editor.session.on('change', () => {
        // this.resizeEditorOnContentChange(editor)
      // });
    }

    const currentHTML = contentBlock.dataset.previousContentBlockHtml

    editor.setValue(currentHTML, currentHTML.length)
    editor.focus()
  },

  getCodeEditorName(container) {
    const contentBlockId = container.dataset.contentBlockId
    return `content-block-${contentBlockId}`
  },

  genTextEditorIdForTextarea(contentBlockId) {
    return `content-block-html-editor-${contentBlockId}`
  },

  saveConventBlockFromCkeditor(e) {
    const { contentBlockWrapper, contentBlock} = this.getContentBlockAndWrapper(e.target);

    if (contentBlockWrapper.classList.contains("-html-edit-mode")) {
      contentBlockWrapper.classList.remove("-html-edit-mode")

      const editorId = this.genTextEditorIdForTextarea(contentBlockWrapper.dataset.contentBlockId)

      let newContent = App.HTMLEditor.instances[editorId].getData().trim()
      // newContent = this.removeWrappingParagraphsFromCkeditorHtml(newContent)

      this.updateContentBlock(
        contentBlock,
        contentBlockWrapper.dataset.contentBlockId,
        newContent
      )
    }
  },

  updateContentBlock(contentBlock, contentBlockId, newContent, resetFoundationState = false) {
    const updatedContentBlock = ProjektStudio.utils.htmlToDomElement(newContent);

    if (resetFoundationState) {
      ProjektStudio.utils.resetFoundationAccordionStateFor(updatedContentBlock)
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
    $(contentBlock).foundation();
  },

  getContentBlockAndWrapper(element) {
    const contentBlockWrapper = this.getParentContentBlockWrapper(element)

    if (!contentBlockWrapper) return {}

    const contentBlock = contentBlockWrapper.querySelector(".projekt-content-block")

    return { contentBlockWrapper, contentBlock};
  },

  getClosestContentBlock(element) {
    return element.closest(".js-projekt-content-block");
  },

  getContentBlock(element) {
    return element.querySelector(".js-projekt-content-block");
  },

  cancelHtmlEditMode(e) {
    const { contentBlockWrapper, contentBlock} = this.getContentBlockAndWrapper(e.target);

    contentBlockWrapper.classList.remove("-html-edit-mode")
    contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;

    $(contentBlock).foundation();
  },

  cancelAiEditMode(e) {
    const { contentBlockWrapper, contentBlock } = this.getContentBlockAndWrapper(e.target);

    // Revert content to previous version if it exists
    if (contentBlock && contentBlock.dataset.previousContentBlockHtml) {
      contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
      $(contentBlock).foundation();
      App.ImageGallery.initialize();
    }

    contentBlockWrapper.classList.remove("-ai-edit-mode")
  },

  storePreviousVersionOfContentBlock(contentBlock, contentBlockWrapper) {
    contentBlock.dataset.previousContentBlockHtml = contentBlock.innerHTML.trim();
    const returnToPrevButton = contentBlockWrapper.querySelector(".js-content-block-reset-to-prev-version")

    returnToPrevButton.disabled = false
  },

  resetPreviosVersionOfContentBlock(contentBlock, contentBlockWrapper) {
    contentBlock.dataset.previousContentBlockHtml = null;
    contentBlockWrapper.scrollIntoView({block: "center"});
    const returnToPrevButton = contentBlockWrapper.querySelector(".js-content-block-reset-to-prev-version")

    returnToPrevButton.disabled = true
  },

  resetContentBlockToPreviousVersion(e) {
    const resetConfirmed = confirm("Möchten Sie die letzte Änderung wirklich zurücksetzen?")

    if (resetConfirmed) {
      const { contentBlock, contentBlockWrapper } = this.getContentBlockAndWrapper(e.target);

      if (contentBlock.dataset.previousContentBlockHtml) {
        contentBlock.innerHTML = contentBlock.dataset.previousContentBlockHtml;
        this.resetPreviosVersionOfContentBlock(contentBlock, contentBlockWrapper)

        this.updateContentBlock(
          contentBlock,
          contentBlockWrapper.dataset.contentBlockId,
          contentBlock.innerHTML.trim()
        )

        setTimeout(() => {
          App.ImageGallery.initialize();
          $(contentBlock).foundation();
        }, 0)
      }
    }
  },
};

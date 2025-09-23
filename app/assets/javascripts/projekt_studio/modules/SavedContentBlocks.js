ProjektStudio.SavedContentBlocks = {
  initialize() {
    this.initEventListeners()

    // Access the session's worker
    ace.config.set("workerPath", "https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12");
  },

  aceInstances: {},

  initEventListeners() {
    $(document).on("click", ".js-toggle-saved-content-block-form", this.toggleNewSavedContentBlockForm.bind(this));

    $(document).on("click", ".js-create-saved-content-block", this.createSavedContentBlock.bind(this));
    $(document).on("click", ".js-cancel-create-saved-content-block", this.cancelCreatingNewSavedContentBlock.bind(this));

    $(document).on("click", ".js-edit-saved-content-block", this.editSavedContentBlock.bind(this));
    $(document).on("click", ".js-update-saved-content-block", this.updateSavedContentBlock.bind(this));
    $(document).on("click", ".js-cancel-update-saved-content-block", this.cancelUpdateSavedContentBlock.bind(this));

    $(document).on("click", ".js-delete-saved-content-block", this.deleteSavedContentBlock.bind(this));

    window.addEventListener('message', this.handleGlobalMessage.bind(this));
  },


  handleGlobalMessage(event) {
    if (event.data) {
      const data = ProjektStudio.utils.parseIframeEventData(event.data);
      const params = data.params

      switch(data.event_type) {
        case "Consul.ProjektStudioConsul.addNewSavedContentBlockOnUI":
          this.addNewSavedContentBlockOnUI(params);
          break;
      }
    }
  },

  toggleNewSavedContentBlockForm(e) {
    const container = this.getFormContainer(e.currentTarget)

    container.classList.toggle("-form-opened")

    if (container.classList.contains("-form-opened")) {
      const editor = this.setupAceEditor(container, '')

      setTimeout(() => {
        editor.container.scrollIntoView({block: "center", inline: "nearest"})
      }, 10)
    }
    else {
      this.cancelCreatingNewSavedContentBlock()
    }
  },

  editSavedContentBlock(e) {
    const container = this.getItemContainer(e.currentTarget)
    const currentHTML = container.querySelector(".js-content-block-template-content").innerHTML.trim()

    const editor = this.setupAceEditor(container, currentHTML)

    container.classList.toggle("-edit-mode")

    setTimeout(() => {
      editor.container.scrollIntoView({block: "center", inline: "nearest"})
    }, 10)

    setTimeout(() => {
      this.resizeEditorOnContentChange(editor)
    }, 100)
  },

  resizeEditorOnContentChange(editor) {
    const lineHeight = 20; // Approximate height of one line in pixels
    const lines = editor.session.getLength();
    const newHeight = lines * lineHeight;
    editor.container.style.height = newHeight + "px";
    editor.resize();
  },

  updateSavedContentBlock(e) {
    const container = this.getItemContainer(e.currentTarget)
    const savedContentBlockId = container.dataset.savedContentBlockId
    const editor = this.getEditorForContainer(container)

    const content = editor.getValue().trim();
    const htmlValidation = ProjektStudio.utils.validateHTML(content);

    if (!htmlValidation.isValid) {
      alert(`${htmlValidation.message}. Issues: ${htmlValidation.issues}`);
      return
    }

    const templateContentElement = container.querySelector(".js-content-block-template-content")
    templateContentElement.innerHTML = content

    const selector = `.js-saved-content-block-item[data-saved-content-block-id="${savedContentBlockId}"] .js-content-block-template-content`
    const allContentBlocksWithThisId = document.querySelectorAll(selector)

    const updateOtherContentBlocks = () => {
      allContentBlocksWithThisId.forEach((templateContentElement) => {
        templateContentElement.innerHTML = content
      })

      const templateElement =
        document
          .querySelector(`.js-projekt-content-block-templates-selector`)
          .content
          .querySelector(`[data-saved-content-block-id="${savedContentBlockId}"] .js-content-block-template-content`)

      templateElement.innerHTML = content;

      this.turnOffEditModeForItem(container)
    }

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame("Dt.ProjektStudio.updateSavedContentBlock", {
        id: savedContentBlockId,
        content
      })
      updateOtherContentBlocks()
    } else {
      $.ajax({
        url: `/admin/saved_content_blocks/${savedContentBlockId}`,
        type: "PATCH",
        data: { saved_content_block: { content }}
      }).then(() => {
        updateOtherContentBlocks()
      })
    }
  },

  cancelUpdateSavedContentBlock(e) {
    const container = this.getItemContainer(e.currentTarget)

    this.turnOffEditModeForItem(container)
  },

  turnOffEditModeForItem(container) {
    const editor = this.getEditorForContainer(container)

    editor.setValue("", -1)

    setTimeout(() => {
      container.classList.remove("-edit-mode")
    }, 10)
  },

  createSavedContentBlock(e) {
    const container = this.getFormContainer(e.currentTarget)
    const editor = this.getEditorForContainer(container)
    const content = editor.getValue();

    editor.setValue("")

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame(
        "Dt.ProjektStudio.createSavedContentBlock",
        { content }
      )
      setTimeout(() => {
        container.classList.remove("-form-opened")
      }, 10)
    } else {
      $.ajax({
        url: `/admin/saved_content_blocks`,
        type: "POST",
        data: { saved_content_block: { content }}
      }).then(({ saved_content_block_item_html }) => {
        container.classList.remove("-form-opened")

        this.addNewSavedContentBlockOnUI({
          saved_content_block_item_html,
          container
        })
      })
    }
  },

  cancelCreatingNewSavedContentBlock(e) {
    const container = this.getFormContainer(e.currentTarget)
    const editor = this.getEditorForContainer(container)
    editor.setValue("", -1)

    setTimeout(() => {
      container.classList.remove("-form-opened")
    }, 10)
  },

  deleteSavedContentBlock(e) {
    const container = this.getItemContainer(e.currentTarget)
    const deleteConfirmed = confirm("Möchten Sie die Vorlage wirklich löschen?")

    if (deleteConfirmed) {
      const savedContentBlockId = container.dataset.savedContentBlockId

      if (ProjektStudio.isEmbedded) {
        ProjektStudio.utils.sendMessageToDtParentFrame(
        "Dt.ProjektStudio.deleteSavedContentBlock",
          { id: savedContentBlockId }
        )
      } else {
        $.ajax({
          url: `/admin/saved_content_blocks/${savedContentBlockId}`,
          type: "DELETE"
        })
      }

      container.remove()

      const selector =`.js-saved-content-block-item[data-saved-content-block-id="${savedContentBlockId}"]`
      const elementsToRemove = document.querySelectorAll(selector)
      // console.log({elementsToRemove})
      elementsToRemove.forEach((element) => element.remove())
    }
  },

  addNewSavedContentBlockOnUI({saved_content_block_item_html, container}) {
    const templatesLists = document.querySelectorAll(".js-saved-content-blocks-list")

    templatesLists.forEach((templatesListElement) => {
      templatesListElement.insertAdjacentHTML("beforeend", saved_content_block_item_html)
    })

    const lastItem = templatesLists.querySelector(".js-saved-content-block-item:last-child")

    lastItem.scrollIntoView({ block: "start" })
  },

  setupAceEditor(container, currentHTML = '') {
    const textarea = container.querySelector("textarea[name='content']")
    const scopedToContentBlockEditorName = this.getEditorName(container)
    let editor = this.aceInstances[scopedToContentBlockEditorName];

    if (!editor) {
      editor = ace.edit(textarea)
      this.aceInstances[scopedToContentBlockEditorName] = editor

      editor.setFontSize(14)
      editor.session.setMode("ace/mode/html");

      editor.session.on('change', () => {
        this.resizeEditorOnContentChange(editor)
      });
    }

    editor.setValue(currentHTML, currentHTML.length)
    editor.focus()

    return editor
  },

  getEditorForContainer(container) {
    const editorName = this.getEditorName(container)

    return this.aceInstances[editorName]
  },

  getEditorName(container) {
    const editorName = container.dataset.editorName

    const surroundingContentBlockId =
      container
        .closest(".js-projekt-content-block-edit-section")
        .dataset
        .contentBlockId

    const scopedToContentBlockEditorName = `${editorName}-content-block-${surroundingContentBlockId}`

    return scopedToContentBlockEditorName
  },

  getFormContainer(element) {
    return element.closest(".js-show-content-block-templates-section")
  },

  getItemContainer(element) {
    return element.closest(".js-saved-content-block-item")
  }
};

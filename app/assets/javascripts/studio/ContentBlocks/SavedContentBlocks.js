App.Studio.ContentBlocks.SavedContentBlocks = {
  initialize() {
    this.initEventListeners()

    // Access the session's worker
    ace.config.set("workerPath", "https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12");
  },

  aceInstances: {},

  initEventListeners() {
    const $document = $(document)

    $document.on("click", ".js-toggle-saved-content-block-form", this.toggleNewSavedContentBlockForm.bind(this));

    $document.on("click", ".js-create-saved-content-block", this.createSavedContentBlock.bind(this));
    $document.on("click", ".js-cancel-create-saved-content-block", this.cancelCreatingNewSavedContentBlock.bind(this));

    $document.on("click", ".js-edit-saved-content-block", this.editSavedContentBlock.bind(this));
    $document.on("click", ".js-update-saved-content-block", this.updateSavedContentBlock.bind(this));
    $document.on("click", ".js-cancel-update-saved-content-block", this.cancelUpdateSavedContentBlock.bind(this));

    $document.on("click", ".js-delete-saved-content-block", this.deleteSavedContentBlock.bind(this));

    window.addEventListener('message', this.handleGlobalMessage.bind(this));
  },


  handleGlobalMessage(event) {
    if (event.data) {
      const data = event.data;
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
    const currentHTML = App.Studio.utils.resetMapEmbeds(
      container.querySelector(".js-content-block-template-content").innerHTML.trim()
    )

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
    const htmlValidation = App.Studio.utils.validateHTML(content);

    if (!htmlValidation.isValid) {
      alert(`${htmlValidation.message}. Issues: ${htmlValidation.issues}`);
      return
    }

    const templateContentElement = container.querySelector(".js-content-block-template-content")
    templateContentElement.innerHTML = content

    App.Studio.ContentBlocks.MapEmbed.hydrateIn(templateContentElement)

    this.turnOffEditModeForItem(container)

    App.Ajax.request({
      url: `/adm/saved_content_blocks/${savedContentBlockId}`,
      type: "PATCH",
      data: { saved_content_block: { content }}
    })
     .then((response) => {
       this.syncTemplateContentFromServer(templateContentElement, response);
       if (response && response.stripped) {
         App.Studio.ContentBlocks.Crud.showSanitizationNotice();
       }
     })
    .catch((response) => {
      if (response.error && response.error.message) {
        alert(`Fehler beim Speichern der Inhaltsblockvorlage: ${response.error.message}`)
      }
      else {
        alert("Fehler beim Speichern der Inhaltsblockvorlage")
      }
    })
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

  getContext() {
    const modal = document.querySelector("#contentBlockTemplatesModal")

    if (modal && modal.dataset.savedContentBlockContext) {
      return modal.dataset.savedContentBlockContext
    }

    return "projekt"
  },

  createSavedContentBlock(e) {
    const container = this.getFormContainer(e.currentTarget)
    const editor = this.getEditorForContainer(container)
    const content = editor.getValue();
    const savedContentBlockType = container.dataset.savedContentBlockType;
    const userSpecific = savedContentBlockType === 'user';

    editor.setValue("")

    App.Ajax.request({
      url: `/adm/saved_content_blocks`,
      type: "POST",
      data: { saved_content_block: { content, user_specific: userSpecific, context: this.getContext() }}
    })
    .then((response) => {
      container.classList.remove("-form-opened")

      this.addNewSavedContentBlockOnUI({
        saved_content_block_item_html: response.saved_content_block_item_html,
        container
      })

      if (response && response.stripped) {
        App.Studio.ContentBlocks.Crud.showSanitizationNotice();
      }
    })
    .catch((response) => {
      if (response.error && response.error.message) {
        alert(`Fehler beim Erstellen der Inhaltsblockvorlage: ${response.error.message}`)
      }
      else {
        alert("Fehler beim Erstellen der Inhaltsblockvorlage")
      }
    })
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

      App.Ajax.request({
        url: `/adm/saved_content_blocks/${savedContentBlockId}`,
        type: "DELETE"
      })
      .then(() => {
        container.remove()

        const selector =`.js-saved-content-block-item[data-saved-content-block-id="${savedContentBlockId}"]`
        const elementsToRemove = document.querySelectorAll(selector)
        elementsToRemove.forEach((element) => element.remove())
      })
      .catch((response) => {
        if (response.error && response.error.message) {
          alert(`Fehler beim Löschen der Inhaltsblockvorlage: ${response.error.message}`)
        }
        else {
          alert("Fehler beim Löschen der Inhaltsblockvorlage")
        }
      })
    }
  },

  addNewSavedContentBlockOnUI({saved_content_block_item_html, container}) {
    const tabPanel = container.closest(".shared-tabs-panel")
    const templatesList = tabPanel.querySelector(".js-saved-content-blocks-list")

    templatesList.insertAdjacentHTML("beforeend", saved_content_block_item_html)

    const lastItem = templatesList.querySelector(".js-saved-content-block-item:last-child")

    lastItem.scrollIntoView({ block: "start" })

    this.highlightAddedItem(lastItem)
  },

  highlightAddedItem(item) {
    const removeHighlight = (e) => {
      if (e.target !== item) return

      item.classList.remove("-highlight-added")
      item.removeEventListener("animationend", removeHighlight)
    }

    item.classList.add("-highlight-added")
    item.addEventListener("animationend", removeHighlight)
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

    const formattedHTML = App.Studio.utils.formatHTML(currentHTML);
    editor.setValue(formattedHTML, -1); // -1 moves cursor to start
    editor.focus()

    return editor
  },

  getEditorForContainer(container) {
    const editorName = this.getEditorName(container)

    return this.aceInstances[editorName]
  },

  getEditorName(container) {
    const editorName = container.dataset.editorName
    const surroundingContentBlockId = App.Studio.ContentBlocks.TemplateSelector.currentContentBlockId

    return `${editorName}-content-block-${surroundingContentBlockId}`
  },

  getFormContainer(element) {
    return element.closest(".js-show-content-block-templates-section")
  },

  getItemContainer(element) {
    return element.closest(".js-saved-content-block-item")
  },

  syncTemplateContentFromServer(templateContentElement, response) {
    if (!response || typeof response.content !== "string") return

    const current = templateContentElement.innerHTML.trim();
    if (current === response.content.trim()) return

    templateContentElement.innerHTML = response.content;

    App.Studio.ContentBlocks.MapEmbed.hydrateIn(templateContentElement);
  }
};

import ace from "ace-builds/src-min/ace"
import 'ace-builds/src-noconflict/mode-html'
import 'ace-builds/src-noconflict/worker-html';
import { sendMessageToDtParentFrame, parseIframeEventData } from "consul/utils/iframeUtils";
import { validateHTML } from "utils/htmlUtils"

// Access the session's worker

ace.config.set("workerPath", "https://cdnjs.cloudflare.com/ajax/libs/ace/1.4.12");

const SavedContentBlocks = {
  initialize() {
    this.initEventListeners()
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
    const htmlValidation = validateHTML(content);

    if (!htmlValidation.isValid) {
      alert(`${htmlValidation.message}. Issues: ${htmlValidation.issues}`);
      return
    }

    const templateContentElement = container.querySelector(".js-content-block-template-content")
    templateContentElement.innerHTML = content

    const selector = `.js-saved-content-block-item[data-saved-content-block-id="${savedContentBlockId}"] .js-content-block-template-content`
    const allContentBlocksWithThisId = document.querySelectorAll(selector)

    allContentBlocksWithThisId.forEach((templateContentElement) => {
      templateContentElement.innerHTML = content
    })

    this.turnOffEditModeForItem(container)

    sendMessageToDtParentFrame("Dt.ProjektStudio.updateSavedContentBlock", {
      id: savedContentBlockId,
      content
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

  createSavedContentBlock(e) {
    const container = this.getFormContainer(e.currentTarget)
    const editor = this.getEditorForContainer(container)
    const content = editor.getValue();

    editor.setValue("")

    setTimeout(() => {
      container.classList.remove("-form-opened")
    }, 10)

    sendMessageToDtParentFrame(
      "Dt.ProjektStudio.createSavedContentBlock",
      { content }
    )
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

      sendMessageToDtParentFrame(
       "Dt.ProjektStudio.deleteSavedContentBlock",
        { id: savedContentBlockId }
      )

      container.remove()

      const selector =`.js-saved-content-block-item[data-saved-content-block-id="${savedContentBlockId}"]`
      const elementsToRemove = document.querySelectorAll(selector)
      // console.log({elementsToRemove})
      elementsToRemove.forEach((element) => element.remove())
    }
  },

  addNewSavedContentBlockOnUI({saved_content_block_item_html}) {
    const templatesLists = document.querySelectorAll(".js-saved-content-blocks-list")

    templatesLists.forEach((templatesListElement) => {
      templatesListElement.insertAdjacentHTML("beforeend", saved_content_block_item_html)
    })
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

  // setAceWorkerValidationIgnoreRules(editor) {
  //   console.log({editor})
  //   var worker = editor.getSession().getWorker();
  //
  //   // Disable specific 'DOCTYPE' linting (or override worker's default behavior)
  //   worker.on("lint", function (messages) {
  //     messages = messages.filter(function (message) {
  //       // Remove the message if it relates to 'DOCTYPE'
  //       return message.row !== 0 || message.text.indexOf('DOCTYPE') === -1;
  //     });
  //     // Return the filtered lint messages
  //     return messages;
  //   });
  // },

  getFormContainer(element) {
    return element.closest(".js-show-content-block-templates-section")
  },

  getItemContainer(element) {
    return element.closest(".js-saved-content-block-item")
  }
};

export default SavedContentBlocks

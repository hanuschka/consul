App.Studio.ContentBlocks.CKEditorMode = {
  aceInstances: {},

  initialize() {
    const $document = $(document);
    $document.on("click", ".js-code-edit-content-block", this.handleEnterCodeEditMode.bind(this));
  },

  switchToHtmlEditMode(contentBlockWrapper) {
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    this.enterHtmlEditMode(contentBlockWrapper, contentBlock);
  },

  handleEnterCodeEditMode(e) {
    const { contentBlockWrapper, contentBlock } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target)
    this.enterCodeEditMode(contentBlockWrapper, contentBlock)
  },

  handleSaveFromCkeditor(e) {
    const { contentBlockWrapper, contentBlock} = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    this.saveFromCkeditor(contentBlockWrapper, contentBlock)
  },

  handleCancelHtmlEditMode(e) {
    const { contentBlockWrapper, contentBlock} = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    this.cancelHtmlEditMode(contentBlockWrapper, contentBlock)
  },

  enterHtmlEditMode(contentBlockWrapper, contentBlock) {
    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-html-edit-mode", "-in-edit-mode")
    contentBlockWrapper.dataset.editMode = 'html';

    const originalContent = contentBlock.innerHTML;
    App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);

    contentBlock.innerHTML = `
      <div class="js-html-edit-mode-original-content" style="display: none;">
        ${originalContent}
      </div>
      <textarea
        name="body"
        id="${this.genTextEditorIdForTextarea(contentBlockWrapper.dataset.contentBlockId)}"
        rows="8"
        class="html-area extended-a js-studio-hide-on-preview"
        style="visibility: hidden; display: none;"
      >
         ${originalContent}
      </textarea>
    `

    App.HTMLEditor.enableCKeditorFor(contentBlock.querySelector("textarea"))
  },

  enterCodeEditMode(contentBlockWrapper, contentBlock) {
    contentBlockWrapper.classList.remove("-highlight-changed")
    contentBlockWrapper.classList.add("-code-edit-mode", "-in-edit-mode")

    App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper)

    const currentHTML = contentBlock.innerHTML;

    contentBlock.innerHTML = `
      <textarea
        name="body"
        rows="8"
        style="visibility: hidden; display: none;">
         ${currentHTML}
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
    }

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

  saveFromCkeditor(contentBlockWrapper, contentBlock) {
    if (contentBlockWrapper.classList.contains("-html-edit-mode")) {
      contentBlockWrapper.classList.remove("-html-edit-mode", "-in-edit-mode")
      contentBlockWrapper.dataset.editMode = '';

      const editorId = this.genTextEditorIdForTextarea(contentBlockWrapper.dataset.contentBlockId)

      let newContent = App.HTMLEditor.instances[editorId].getData().trim()

      App.Studio.ContentBlocks.Crud.updateContentBlock(
        contentBlock,
        newContent
      )
    }
  },

  updateContentBlockFromCKEditor(contentBlockWrapper, contentBlock) {
    const editorId = this.genTextEditorIdForTextarea(contentBlockWrapper.dataset.contentBlockId);
    if (App.HTMLEditor.instances[editorId]) {
      const newContent = App.HTMLEditor.instances[editorId].getData().trim();
      contentBlock.innerHTML = newContent;
    }
  },

  exitHtmlEditMode(contentBlockWrapper, restoreContent = false) {
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);

    if (restoreContent) {
      App.Studio.ContentBlocks.DraftStore.restorePreviousVersion(contentBlock);
    } else {
      this.updateContentBlockFromCKEditor(contentBlockWrapper, contentBlock);
    }

    contentBlockWrapper.classList.remove("-html-edit-mode", "-in-edit-mode")
    contentBlockWrapper.dataset.editMode = '';

    App.Studio.ContentBlocks.DomHelpers.scrollToContentBlockTop(contentBlockWrapper);
  },

  cancelHtmlEditMode(contentBlockWrapper, contentBlock) {
    this.exitHtmlEditMode(contentBlockWrapper, true);
  }
};

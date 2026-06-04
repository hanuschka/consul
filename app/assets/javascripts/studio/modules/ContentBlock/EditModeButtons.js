App.ContentBlockEditor.EditModeButtons = {
  initialize() {
    const $document = $(document);
    $document.on("click", ".js-save-content-block", this.handleSave.bind(this));
    $document.on("click", ".js-cancel-content-block", this.handleCancel.bind(this));
  },

  handleSave(e) {
    const button = e.currentTarget;
    const contentBlockWrapper = button.closest(".projekt-content-block-wrapper");
    const editMode = contentBlockWrapper.dataset.editMode;

    switch(editMode) {
      case "ai":
        App.ContentBlockEditor.AiEditMode.saveContentBlockAndExit(e);
        break;
      case "simple":
        App.ContentBlockEditor.SimpleEditMode.saveContentBlockFromSimpleMode(e);
        break;
      case "html":
        App.ContentBlockEditor.CKEditorMode.handleSaveFromCkeditor(e);
        break;
      case "code":
        App.ContentBlockEditor.CodeEditMode.saveContentBlockAndExit(e);
        break;
    }
  },

  handleCancel(e) {
    const button = e.currentTarget;
    const contentBlockWrapper = button.closest(".projekt-content-block-wrapper");
    const editMode = contentBlockWrapper.dataset.editMode;

    switch(editMode) {
      case "ai":
        App.ContentBlockEditor.AiEditMode.cancelAiEditMode(e);
        break;
      case "simple":
        App.ContentBlockEditor.SimpleEditMode.cancelSimpleEditMode(e);
        break;
      case "html":
        App.ContentBlockEditor.CKEditorMode.handleCancelHtmlEditMode(e);
        break;
      case "code":
        App.ContentBlockEditor.CodeEditMode.cancelCodeEditMode(e);
        break;
    }
  }
};

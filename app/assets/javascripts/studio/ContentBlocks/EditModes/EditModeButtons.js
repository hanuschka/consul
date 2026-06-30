App.Studio.ContentBlocks.EditModeButtons = {
  initialize() {
    const $document = $(document);
    $document.on("click", ".js-save-content-block", this.handleSave.bind(this));
    $document.on("click", ".js-cancel-content-block", this.handleCancel.bind(this));
  },

  handleSave(e) {
    const button = e.currentTarget;
    const contentBlockWrapper = button.closest(".custom-content-block-wrapper");
    const editMode = contentBlockWrapper.dataset.editMode;

    switch(editMode) {
      case "ai":
        App.Studio.ContentBlocks.AiEditMode.saveContentBlockAndExit(e);
        break;
      case "simple":
        App.Studio.ContentBlocks.SimpleEditMode.saveContentBlockFromSimpleMode(e);
        break;
      case "html":
        App.Studio.ContentBlocks.CKEditorMode.handleSaveFromCkeditor(e);
        break;
      case "code":
        App.Studio.ContentBlocks.CodeEditMode.saveContentBlockAndExit(e);
        break;
    }
  },

  handleCancel(e) {
    const button = e.currentTarget;
    const contentBlockWrapper = button.closest(".custom-content-block-wrapper");
    const editMode = contentBlockWrapper.dataset.editMode;

    switch(editMode) {
      case "ai":
        App.Studio.ContentBlocks.AiEditMode.cancelAiEditMode(e);
        break;
      case "simple":
        App.Studio.ContentBlocks.SimpleEditMode.cancelSimpleEditMode(e);
        break;
      case "html":
        App.Studio.ContentBlocks.CKEditorMode.handleCancelHtmlEditMode(e);
        break;
      case "code":
        App.Studio.ContentBlocks.CodeEditMode.cancelCodeEditMode(e);
        break;
    }
  }
};

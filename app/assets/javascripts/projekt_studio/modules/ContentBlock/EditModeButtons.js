ProjektStudio.ContentBlock.EditModeButtons = {
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
        ProjektStudio.ContentBlock.AiEditMode.saveContentBlockAndExit(e);
        break;
      case "simple":
        ProjektStudio.ContentBlock.SimpleEditMode.saveContentBlockFromSimpleMode(e);
        break;
      case "html":
        ProjektStudio.ContentBlock.CKEditorMode.handleSaveFromCkeditor(e);
        break;
      case "code":
        ProjektStudio.ContentBlock.CodeEditMode.saveContentBlockAndExit(e);
        break;
    }
  },

  handleCancel(e) {
    const button = e.currentTarget;
    const contentBlockWrapper = button.closest(".projekt-content-block-wrapper");
    const editMode = contentBlockWrapper.dataset.editMode;

    switch(editMode) {
      case "ai":
        ProjektStudio.ContentBlock.AiEditMode.cancelAiEditMode(e);
        break;
      case "simple":
        ProjektStudio.ContentBlock.SimpleEditMode.cancelSimpleEditMode(e);
        break;
      case "html":
        ProjektStudio.ContentBlock.CKEditorMode.handleCancelHtmlEditMode(e);
        break;
      case "code":
        ProjektStudio.ContentBlock.CodeEditMode.cancelCodeEditMode(e);
        break;
    }
  }
};

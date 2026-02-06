window.ProjektStudio = {
  modules: {},
  templateFunctions: {},
  utils: {},
  ContentBlock: {},
  config: {},

  initialized: false,

  initialize() {
    if (this.initialized) return

    if (window.parent) {
      this.loadConfig();
      ProjektStudio.Sidebar.initialize()
      ProjektStudio.PhasesTabs.initialize()
      ProjektStudio.Banner.initialize()

      ProjektStudio.ProjektStart.initialize()
      ProjektStudio.BuildWithPrompt.initialize()

      // Initialize ContentBlock submodules
      ProjektStudio.ContentBlockTemplateSelector.initialize()
      ProjektStudio.ContentBlock.Render.initialize()
      ProjektStudio.ContentBlock.DragDrop.initialize()
      ProjektStudio.ContentBlock.Crud.initialize()
      ProjektStudio.ContentBlock.ChangeHistory.initialize()
      ProjektStudio.ContentBlock.CKEditorMode.initialize()
      ProjektStudio.ContentBlock.DtAiEditMode.initialize()

      ProjektStudio.ContentBlock.EditModeSwitcher.initialize()
      ProjektStudio.ContentBlock.EditModeButtons.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.TextFormat.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.HeaderEdit.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.LinkEdit.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.ListEdit.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.ImageGalleryDialog.initialize()
      ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.initialize()
      ProjektStudio.ContentBlock.AiEditMode.initialize()
      ProjektStudio.ContentBlock.CodeEditMode.initialize()
      ProjektStudio.ContentBlock.Copy.initialize()
      ProjektStudio.SavedContentBlocks.initialize()
      ProjektStudio.FileImport.initialize()
      ProjektStudio.ToggleBackground.initialize()
      // ExplainWithAi.initialize()

      this.initialized = true;
    }
  },

  get isEmbedded() {
    return window.self !== window.top;
  },

  loadConfig() {
    const projektPage = document.querySelector(".js-projekt-page");
    this.config.defaultMarginBottom = parseInt(projektPage.dataset.defaultMarginBottom);
  },

  getCurrentProjektId() {
    return  document.querySelector(".js-projekt-page").dataset.projektId;
  },

  reinitializeUI() {
    // console.log("reinitialize ProjektStudio")
  },

  isProjektPage() {
    return !!document.querySelector(".js-projekt-page")
  }
}




// Check if DOMContentLoaded event already finished
// if so, the initialize ProjektStudio immidiately,
// othewise init it on DOMContentLoaded
if (
  document.readyState === "complete"
  || document.readyState === "loaded"
  || document.readyState === "interactive"
) {
  ProjektStudio.initialize()
}
else {
  document.addEventListener("DOMContentLoaded", () => {
    ProjektStudio.initialize()
  })
}

// Add event listener to reinit ProjektStudio UI on turbolinks page load
// Use capture option to ensure this event will fire before any other
// "turbolinks:load" events
document.addEventListener("turbolinks:load", () => {
  ProjektStudio.reinitializeUI()
}, { capture: true })

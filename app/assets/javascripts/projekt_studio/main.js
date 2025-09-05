window.ProjektStudio = {
  modules: {},
  templateFunctions: {},
  utils: {},

  initialized: false,

  initialize() {
    if (this.initialized) return

    if (window.parent) {
      ProjektStudio.modules.Sidebar.initialize()
      ProjektStudio.modules.PhasesTabs.initialize()
      ProjektStudio.modules.Banner.initialize()
      ProjektStudio.modules.ContentBlocks.initialize()
      ProjektStudio.PreviewMode.initialize()
      // ExplainWithAi.initialize()
      // SavedContentBlocks.initialize()


      this.initialized = true;
    }
  },

  get isEmbedded() {
    return window.parent !== window.top
  },

  getCurrentProjektId() {
    return  document.querySelector(".js-projekt-page").dataset.projektId;
  },

  reinitializeUI() {
    console.log("reinitialize ProjektStudio")

    // ContentBlocks.initUI()
    // PhasesTabs.initUI()
    // ExplainWithAi.initUI()
  },

  // requestLoadContentBlockTemplates() {
  //   if (this.isProjektPage()) {
  //     sendMessageToDtParentFrame(
  //       "Dt.ProjektStudio.loadContentBlockTemplates"
  //     )
  //   }
  // },

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

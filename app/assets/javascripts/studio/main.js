window.ProjektStudio = {
  modules: {},
  templateFunctions: {},
  utils: {},
  ContentBlock: App.ContentBlockEditor,
  config: {},

  // Fallback used outside projekt-studio pages (e.g. inline site content
  // blocks on the homepage/sidebar), where loadConfig never runs and
  // config.defaultMarginBottom stays undefined.
  FALLBACK_MARGIN_BOTTOM: 20,

  initialized: false,

  initialize() {
    if (this.initialized) return
    if (!this.isProjektPage()) return

    this.loadConfig();

    ProjektStudio.Sidebar.initialize()
    ProjektStudio.PhasesTabs.initialize()
    ProjektStudio.Banner.initialize()

    ProjektStudio.ProjektStart.initialize()
    ProjektStudio.BuildWithPrompt.initialize()
    App.ContentBlockEditor.CreateWithAi.initialize()

    // Initialize ContentBlock submodules
    App.ContentBlockEditor.Render.initialize()
    App.ContentBlockEditor.DragDrop.initialize()

    App.Studio.initContentBlockModules()

    App.ContentBlockEditor.SavedContentBlocks.initialize()
    ProjektStudio.FileImport.initialize()
    ProjektStudio.ToggleBackground.initialize()
    // ExplainWithAi.initialize()

    this.initialized = true;
  },

  get isEmbedded() {
    return window.self !== window.top;
  },

  loadConfig() {
    const projektPage = document.querySelector(".js-projekt-page");
    this.config.defaultMarginBottom = parseInt(projektPage.dataset.defaultMarginBottom);
    this.config.aiAvailable = projektPage.dataset.aiAvailable === "true";
  },

  getCurrentProjektId() {
    return  document.querySelector(".js-projekt-page").dataset.projektId;
  },

  getDefaultMarginBottom() {
    const configured = this.config.defaultMarginBottom;

    return Number.isInteger(configured) ? configured : this.FALLBACK_MARGIN_BOTTOM;
  },

  reinitializeUI() {
    if (!this.isProjektPage()) return

    this.initialized = false;
    this.initialize();
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

// Reinit ProjektStudio UI on turbolinks navigation (not initial page load)
// Use capture option to ensure this event will fire before any other
// "turbolinks:load" events
document.addEventListener("turbolinks:load", () => {
  if (ProjektStudio.initialLoadComplete) {
    ProjektStudio.reinitializeUI()
  }

  ProjektStudio.initialLoadComplete = true
}, { capture: true })

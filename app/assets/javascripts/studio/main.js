window.App = window.App || {};
window.App.Studio = window.App.Studio || {};

window.App.Studio.Projekt = {
  modules: {},
  templateFunctions: {},
  ContentBlock: App.Studio.ContentBlocks,
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

    App.Studio.Projekt.Sidebar.initialize()
    App.Studio.Projekt.PhasesTabs.initialize()
    App.Studio.Projekt.Banner.initialize()

    App.Studio.Projekt.ProjektStart.initialize()
    App.Studio.Projekt.AiBuildWithPrompt.initialize()
    App.Studio.ContentBlocks.CreateWithAi.initialize()

    // Initialize ContentBlock submodules
    App.Studio.ContentBlocks.Render.initialize()
    App.Studio.ContentBlocks.DragDrop.initialize()

    App.Studio.initContentBlockModules()

    App.Studio.ContentBlocks.SavedContentBlocks.initialize()
    App.Studio.Projekt.AiFileImport.initialize()
    App.Studio.Projekt.ToggleBackground.initialize()
    // ExplainWithAi.initialize()

    this.initialized = true;
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
// if so, the initialize App.Studio.Projekt immidiately,
// othewise init it on DOMContentLoaded
if (
  document.readyState === "complete"
  || document.readyState === "loaded"
  || document.readyState === "interactive"
) {
  App.Studio.Projekt.initialize()
}
else {
  document.addEventListener("DOMContentLoaded", () => {
    App.Studio.Projekt.initialize()
  })
}

// Reinit App.Studio.Projekt UI on turbolinks navigation (not initial page load)
// Use capture option to ensure this event will fire before any other
// "turbolinks:load" events
document.addEventListener("turbolinks:load", () => {
  if (App.Studio.Projekt.initialLoadComplete) {
    App.Studio.Projekt.reinitializeUI()
  }

  App.Studio.Projekt.initialLoadComplete = true
}, { capture: true })

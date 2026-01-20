ProjektStudio.PreviewMode = {
  initialized: false,
  initialize() {
    if (this.initialized) {
      return
    }

    window.addEventListener('message', this.handleGlobalMessage.bind(this));

    const $document = $(document);
    $document.on("click", ".js-turn-on-preview-mode-button", this.handlePreviewModeButtonToggle.bind(this));

    this.initialized = true;
  },

  handleGlobalMessage(event) {
    if (event.data) {
      const data = event.data;
      const params = data.params

      switch(data.event_type) {
        case "togglePreviewMode":
          this.togglePreviewMode(params.activated);
          break;
      }
    }
  },

  handlePreviewModeButtonToggle(e) {
    const button = e.currentTarget;
    button.classList.toggle("-enabled")
    const previewModeEnabled = button.classList.contains("-enabled");

    const textElement = button.querySelector(".js-projekt-studio-preview-button-text")
    const text = previewModeEnabled ? "Vorschaumodus aktiv" : "Vorschaumodus"
    textElement.innerText = text

    this.togglePreviewMode(previewModeEnabled)
  },

  togglePreviewMode(activated) {
    window.scrollTo(0, 0);

    document
      .body
      .classList
      .toggle("-preview-mode");

    const previewModeEnabled = document.body.classList.contains("-preview-mode")

    const projektInfo = document.querySelector(".js-sidebar-projekt-info")

    if (projektInfo) {
      const projektInfoContent = projektInfo.querySelector(".custom-content-block-body")

      if (!projektInfoContent) {
        projektInfo.classList.toggle("hide", activated)
      }
    }

    const sdgList = document.querySelector(".js-sidebar-card .js-sdg-goal-tag-list")
    const anyCheckedSDG = sdgList.querySelector('input:checked')
    const sdgSidebarCard = sdgList.closest(".js-sidebar-card")
    const categoriesList = document.querySelector(".js-sidebar-card .categories--simple-selector")
    const anyCheckedCategory = categoriesList.querySelector('.js-add-tag-link.selected')
    const categoriesSidebarCard = categoriesList.closest(".js-sidebar-card")
    const deactivatedPhases = document.querySelectorAll(".js-projekt-phase-tab.-deactivated")

    // const $sidebarAdminControlls = $('.js-sidebar-admin-controlls');
    $(".js-sidebar-card-edit-link").toggle(!previewModeEnabled)
    $(".projekt-banner-edit-field--controlls").toggle(!previewModeEnabled)
    $(".js-projekt-footer-phase-tab--add-new").toggle(!previewModeEnabled)
    $(".js-projekt-studio-hide-on-preview").toggle(!previewModeEnabled)
    $(".js-content-block-ai-edit-popup").toggle(!previewModeEnabled)

    console.log("anyCheckedSDG", anyCheckedSDG)
    console.log("anyCheckedCategory", anyCheckedCategory)

    if (previewModeEnabled) {
      if (!anyCheckedSDG) {
        $(sdgSidebarCard).hide()
      }
      if (!anyCheckedCategory) {
        $(categoriesSidebarCard).hide()
      }

      $(deactivatedPhases).hide()
    } else {
      $(sdgSidebarCard).show()
      $(categoriesSidebarCard).show()

      $(deactivatedPhases).show()
    }
  },

  postMessage(eventType, params) {
    if (window.parent) {
      window.parent.postMessage(
        JSON.stringify({
          event_type: eventType,
          params
        }),
        '*');
    }
  },
};

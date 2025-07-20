// import { parseIframeEventData } from "consul/utils/iframeUtils";

ProjektStudio.PreviewMode = {
  initialized: false,
  initialize() {
    if (this.initialized) {
      return
    }

    window.addEventListener('message', this.handleGlobalMessage.bind(this));

    this.initialized = true;
  },

  handleGlobalMessage(event) {
    if (event.data) {
      const data = ProjektStudio.utils.parseIframeEventData(event.data);
      const params = data.params

      switch(data.event_type) {
        case "togglePreviewMode":
          this.togglePreviewMode(params);
          break;
      }
    }
  },

  togglePreviewMode(params) {
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
        projektInfo.classList.toggle("hide", params.activated)
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
    //
    $(".js-sidebar-card-edit-link").toggle(!previewModeEnabled)
    $(".frame-edit-field--controlls").toggle(!previewModeEnabled)

    if (previewModeEnabled) {
      if (!anyCheckedSDG) {
        sdgSidebarCard.style = "display: none"
      }
      if (!anyCheckedCategory) {
        categoriesSidebarCard.style = "display: none"
      }

      deactivatedPhases.forEach((element) => {
        element.style.display = "none"
      })
    } else {
      sdgSidebarCard.style = "display: block"
      categoriesSidebarCard.style = "display: block"

      deactivatedPhases.forEach((element) => {
        element.style.display = "block"
      })
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

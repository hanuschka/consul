// import { sendMessageToDtParentFrame } from "consul/utils/iframeUtils";

ProjektStudio.modules.PhasesTabs = {
  initialized: false,
  initialize() {
    if (!this.initialized) {
      this.initEventListeners()
    }

    this.initUI()

    this.initialized = true;
  },

  initEventListeners() {
    $(document).on("click", ".js-toggle-projekt-phase-visibility-button", this.toggleProjektPhaseActiveState.bind(this));
    $(document).on("click", ".js-toggle-projekt-phase-default", this.toggleProjektPhaseDefaultState.bind(this));
    $(document).on("click", ".js-delete-projekt-phase", this.deleteProjektPhase.bind(this));
    $(document).on("click", ".js-send-notifications-for-projekt-phase", this.sendNotificationsForProjektPhase.bind(this));
  },

  initUI() {
    const $phasesList = $(".js-phases-list");

    if ($phasesList.length === 0) return;

    $(".js-phases-list").sortable({
      scrollSpeed: 20,
      scrollSensitivity: 100,
      handle: ".js-projekt-phase-move",
      update: (e) => {
        this.handleProjektPhaseSort(e)
      }
    });
  },

  handleProjektPhaseSort(e) {
    var ordered_list = $(e.target).sortable("toArray", {
      attribute: "data-projekt-phase-id"
    });
    const projektId = ProjektStudio.getCurrentProjektId();

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame("reorderProjektPhases", { ordered_list })
    } else {
      $.ajax({
        url: `/admin/projekts/${projektId}/projekt_phases/order_phases`,
        type: "POST",
        dataType: "json",
        data: {
          ordered_list
        }
      })
    }
  },

  async toggleProjektPhaseActiveState(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");

    tab.classList.toggle("-deactivated");

    const active = !tab.classList.contains("-deactivated")
    const icon = e.currentTarget.querySelector("i")
    const projektId = ProjektStudio.getCurrentProjektId();
    const projektPhaseId = tab.dataset.projektPhaseId

    icon.classList.toggle("fa-eye", !active)
    icon.classList.toggle("fa-eye-slash", active)

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame("toggleProjektPhaseActiveState", { projekt_phase_id: tab.dataset.projektPhaseId, active })
    } else {
      $.ajax({
        url: `/admin/projekts/${projektId}/projekt_phases/${projektPhaseId}/toggle_active_status`,
        type: "PATCH",
        dataType: "json",
        data: {
          projekt:  {
            phase_attributes: {
              active: active
            }
          }
        }
      })
    }
  },


  toggleProjektPhaseDefaultState(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");

    tab.classList.toggle("-default-phase");
    const phaseId = tab.dataset.projektPhaseId

    $(`.js-projekt-phase-tab:not([data-projekt-phase-id="${phaseId}"])`)
      .removeClass("-default-phase")
      .find(".fa-gem")
      .removeClass("fa-gem")
      .addClass("fa-thumbtack");

    const isDefault = tab.classList.contains("-default-phase")
    const icon = e.currentTarget.querySelector("i")
    const projektId = ProjektStudio.getCurrentProjektId();

    icon.classList.toggle("fa-thumbtack", !isDefault)
    icon.classList.toggle("fa-gem", isDefault)

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame(
        "toggleProjektPhaseDefaultState",
        { projekt_phase_id: phaseId, is_default: isDefault }
      )
    } else {
      $.ajax({
        url: `/admin/projekts/${projektId}/update_standard_phase`,
        type: "PATCH",
        dataType: "json",
        data: {
          default_footer_tab: {
            id: phaseId
          }
        }
      })
    }
  },

  deleteProjektPhase(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");
    const phaseName = tab.querySelector("h4").innerText;
    const deleteConfirmed = confirm(`Do you really want to delete ${phaseName} phase?`)

    if (deleteConfirmed) {
      const phaseId = tab.dataset.projektPhaseId
      tab.remove()

      if (ProjektStudio.isEmbedded) {
        ProjektStudio.utils.sendMessageToDtParentFrame(
          "deleteProjektPhase",
          { projekt_phase_id: phaseId }
        )
      } else {
        $.ajax({
          url: `/admin/projekt_phases/${phaseId}`,
          type: "DELETE",
          dataType: "json"
        })
      }
    }
  },

  sendNotificationsForProjektPhase(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");
    const phaseName = tab.querySelector("h4").innerText;
    const sendConfirmed = confirm(`Do you really want to send notifications for ${phaseName} phase?`)

    if (sendConfirmed) {
      const phaseId = tab.dataset.projektPhaseId
      const resource_type = e.currentTarget.dataset.resourceType
      const resource_id = e.currentTarget.dataset.resourceId

      sendMessageToDtParentFrame(
        "sendNotificationsForProjektPhase",
        {
          projekt_phase_id: phaseId, resource_type, resource_id
        }
      )
    }
  },
};

// import { sendMessageToDtParentFrame } from "consul/utils/iframeUtils";

ProjektStudio.PhasesTabs = {
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
        var ordered_list = $(e.target).sortable("toArray", {
          attribute: "data-record-id"
        });

        sendMessageToDtParentFrame("reorderProjektPhases", { ordered_list })
      }
    });
  },

  async toggleProjektPhaseActiveState(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");

    tab.classList.toggle("-deactivated");

    const active = !tab.classList.contains("-deactivated")
    const icon = e.currentTarget.querySelector("i")
    icon.classList.toggle("fa-eye", !active)
    icon.classList.toggle("fa-eye-slash", active)

    sendMessageToDtParentFrame("toggleProjektPhaseActiveState", { projekt_phase_id: tab.dataset.projektPhaseId, active })
    // await patch(`/consul/projekt_phases/${projekt_phase_id}`, { body: {
    //    projekt_phase: { active }
    // }});
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

    const is_default = tab.classList.contains("-default-phase")
    const icon = e.currentTarget.querySelector("i")
    icon.classList.toggle("fa-thumbtack", !is_default)
    icon.classList.toggle("fa-gem", is_default)

    sendMessageToDtParentFrame(
      "toggleProjektPhaseDefaultState",
      { projekt_phase_id: phaseId, is_default }
    )
  },

  deleteProjektPhase(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");
    const phaseName = tab.querySelector("h4").innerText;
    const deleteConfirmed = confirm(`Do you really want to delete ${phaseName} phase?`)

    if (deleteConfirmed) {
      const phaseId = tab.dataset.projektPhaseId
      tab.remove()

      sendMessageToDtParentFrame(
        "deleteProjektPhase",
        { projekt_phase_id: phaseId }
      )
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

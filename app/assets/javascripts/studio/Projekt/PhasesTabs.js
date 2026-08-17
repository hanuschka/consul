App.Studio.Projekt.PhasesTabs = {
  initialized: false,
  initialize() {
    if (!this.initialized) {
      this.initEventListeners()
    }

    this.initUI()

    this.initialized = true;
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-toggle-projekt-phase-visibility-button", this.toggleProjektPhaseActiveState.bind(this));
    $document.on("click", ".js-toggle-projekt-phase-default", this.toggleProjektPhaseDefaultState.bind(this));
    $document.on("click", ".js-delete-projekt-phase", this.deleteProjektPhase.bind(this));
    $document.on("click", ".js-send-notifications-for-projekt-phase", this.sendNotificationsForProjektPhase.bind(this));
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
    const projektId = App.Studio.Projekt.getCurrentProjektId();

    $.ajax({
      url: `/adm/projekts/${projektId}/phases/reorder`,
      type: "PATCH",
      dataType: "json",
      contentType: "application/json",
      data: JSON.stringify({
        tree: ordered_list.map((id) => ({ id }))
      })
    })
  },

  async toggleProjektPhaseActiveState(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");

    tab.classList.toggle("-deactivated");

    const active = !tab.classList.contains("-deactivated")
    const icon = e.currentTarget.querySelector("i")
    const projektPhaseId = tab.dataset.projektPhaseId

    icon.classList.toggle("fa-eye", !active)
    icon.classList.toggle("fa-eye-slash", active)
    const dataset = e.currentTarget.dataset;
    App.Studio.utils.updateRichTooltipTitle(e.currentTarget, active ? dataset.hideTitle : dataset.showTitle);

    $.ajax({
      url: `/adm/projekts/phases/${projektPhaseId}/toggle_active`,
      type: "PATCH",
      dataType: "json"
    })
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
    const projektId = App.Studio.Projekt.getCurrentProjektId();

    icon.classList.toggle("fa-thumbtack", !isDefault)
    icon.classList.toggle("fa-gem", isDefault)
    const dataset = e.currentTarget.dataset;
    App.Studio.utils.updateRichTooltipTitle(e.currentTarget, isDefault ? dataset.makeDefaultTitle : dataset.unsetDefaultTitle);

    $.ajax({
      url: `/adm/projekts/${projektId}/update_default_phase`,
      type: "PATCH",
      dataType: "json",
      data: {
        projekt_phase_id: phaseId,
        projekt_phase: {
          default_phase: isDefault
        }
      }
    })
  },

  deleteProjektPhase(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");
    const phaseName = tab.querySelector(".js-projekt-phase-title").innerText;
    const deleteConfirmed = confirm(`Möchten Sie die Phase ${phaseName} wirklich löschen?`)

    if (deleteConfirmed) {
      const phaseId = tab.dataset.projektPhaseId
      tab.remove()

      $.ajax({
        url: `/adm/projekts/phases/${phaseId}`,
        type: "DELETE",
        dataType: "json"
      })
    }
  },

  sendNotificationsForProjektPhase(e) {
    const tab = e.currentTarget.closest(".js-projekt-phase-tab");
    const phaseName = tab.querySelector("h4").innerText;
    const sendConfirmed = confirm(`Möchten Sie wirklich Benachrichtigungen für die Phase ${phaseName} senden?`)

    if (sendConfirmed) {
      const phaseId = tab.dataset.projektPhaseId
      // const resource_type = e.currentTarget.dataset.resourceType
      // const resource_id = e.currentTarget.dataset.resourceId

      $.ajax({
        url: `/adm/projekts/phases/${phaseId}/send_notifications`,
        type: "POST",
        dataType: "json"
      })
    }
  },
};

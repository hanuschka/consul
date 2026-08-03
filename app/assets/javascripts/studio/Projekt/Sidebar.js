App.Studio.Projekt.Sidebar = {
  initialized: false,
  initialize() {
    if (this.initialized) {
      return
    }

    const $document = $(document);

    $document.on("change", ".js-update-projekt-form input",
      App.Studio.utils.debounce(this.handleUpdateProjekt.bind(this), 1000)
    );
    $document.on("click", ".js-sidebar-section-toggle-visibility",
      this.toggleSidebarSectionVisibility.bind(this)
    );

    this.initialized = true;
  },

  handleUpdateProjekt(e) {
    e.preventDefault()

    const form = e.currentTarget.form;

      $.ajax({
        url: form.action,
        type: "PATCH",
        dataType: "json",
        data: App.Studio.utils.formElementToUrlParams(form)
      })
  },

  toggleSidebarSectionVisibility(e) {
    const sectionWrapper = e.currentTarget.closest(".js-projekt-section-data-wrapper, .js-toggle-section-with-setting")
    const sectionDeactivatedOld = sectionWrapper.classList.contains("-deactivated");

    sectionWrapper.classList.toggle("-deactivated", !sectionDeactivatedOld);
    const sectionDeactivatedNew = sectionWrapper.classList.contains("-deactivated");

    const iconClassList = e.currentTarget.querySelector("i").classList;

    iconClassList.toggle("fa-eye-slash", !sectionDeactivatedNew);
    iconClassList.toggle("fa-eye", sectionDeactivatedNew);

    const newTitle = sectionDeactivatedNew ? e.currentTarget.dataset.offTitle : e.currentTarget.dataset.onTitle;
    App.Studio.utils.updateRichTooltipTitle(e.currentTarget, newTitle);

    // const settingKey = sectionWrapper.dataset.projektSettingKey;
    const settingId = sectionWrapper.dataset.projektSettingId;
    const settingValue = sectionDeactivatedNew  ? "" : "active"

    $.ajax({
      url: `/adm/projekts/projekt_settings/${settingId}`,
      type: "PATCH",
      dataType: "json",
      data: {
        "projekt_setting[value]": settingValue
      }
    })
  }
};

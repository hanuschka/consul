window.ProjektStudio.Sidebar = {
  initialized: false,
  initialize() {
    if (this.initialized) {
      return
    }

    console.log("Sidebar initialized")
    $(document).on("change", ".js-update-projekt-form input",
      ProjektStudio.utils.debounce(this.handleUpdateProjekt.bind(this), 1000)
    );
    $(document).on("click", ".js-sidebar-section-toggle-visibility",
      this.toggleSidebarSectionVisibility.bind(this)
    );

    this.initialized = true;
  },

  handleUpdateProjekt(e) {
    e.preventDefault()

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame(
        "updateProjekt",
        formElementToUrlParams(e.currentTarget.form)
      )
    } else {
      $.ajax({
        url: `/admin/projekts/${ProjektStudio.getCurrentProjektId()}`,
        type: "PATCH",
        dataType: "json",
        data: ProjektStudio.utils.formElementToUrlParams(e.currentTarget.form)
      })
    }
  },

  toggleSidebarSectionVisibility(e) {
    const sectionWrapper = e.currentTarget.closest(".js-projekt-section-data-wrapper, .js-toggle-section-with-setting")
    const sectionDeactivatedOld = sectionWrapper.classList.contains("-deactivated");

    sectionWrapper.classList.toggle("-deactivated", !sectionDeactivatedOld);
    const sectionDeactivatedNew = sectionWrapper.classList.contains("-deactivated");

    const iconClassList = e.currentTarget.querySelector("i").classList;

    iconClassList.toggle("fa-eye-slash", !sectionDeactivatedNew);
    iconClassList.toggle("fa-eye", sectionDeactivatedNew);

    const settingKey = sectionWrapper.dataset.projektSettingKey;
    const settingId = sectionWrapper.dataset.projektSettingId;
    const settingValue = sectionDeactivatedNew  ? "" : "active"
    const projektId = ProjektStudio.getCurrentProjektId();

    if (ProjektStudio.isEmbedded) {
      ProjektStudio.utils.sendMessageToDtParentFrame("updateProjektSetting", {
        key: settingKey, value: settingValue
      })
    } else {
      $.ajax({
        url: `/admin/projekts/${settingId}/settings/${projektId}`,
        type: "PATCH",
        dataType: "json",
        data: {
          "projekt_setting[value]": settingValue
        }
      })
    }
  }
};

console.log("After sidebar define")

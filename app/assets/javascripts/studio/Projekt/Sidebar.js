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
<<<<<<< HEAD:app/assets/javascripts/studio/Projekt/Sidebar.js
        url: `/admin/projekts/${App.Studio.Projekt.getCurrentProjektId()}`,
=======
        url: form.action,
>>>>>>> new-connection:app/assets/javascripts/studio/modules/Sidebar.js
        type: "PATCH",
        dataType: "json",
        headers: {
          'X-Embedded-Frame': App.Studio.Projekt.isEmbedded
        },
<<<<<<< HEAD:app/assets/javascripts/studio/Projekt/Sidebar.js
        data: App.Studio.utils.formElementToUrlParams(e.currentTarget.form)
=======
        data: ProjektStudio.utils.formElementToUrlParams(form)
>>>>>>> new-connection:app/assets/javascripts/studio/modules/Sidebar.js
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
<<<<<<< HEAD:app/assets/javascripts/studio/Projekt/Sidebar.js
    const projektId = App.Studio.Projekt.getCurrentProjektId();
=======
>>>>>>> new-connection:app/assets/javascripts/studio/modules/Sidebar.js

    $.ajax({
      url: `/adm/projekts/projekt_settings/${settingId}`,
      type: "PATCH",
      dataType: "json",
<<<<<<< HEAD:app/assets/javascripts/studio/Projekt/Sidebar.js
      headers: {
        'X-Embedded-Frame': App.Studio.Projekt.isEmbedded
      },
=======
>>>>>>> new-connection:app/assets/javascripts/studio/modules/Sidebar.js
      data: {
        "projekt_setting[value]": settingValue
      }
    })
  }
};

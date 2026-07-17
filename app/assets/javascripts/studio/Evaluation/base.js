(function() {
  "use strict";

  App.Studio.Evaluation = {
    initialize() {
      // Window-level flag: App.Studio.Projekt re-runs initialize() on every
      // turbolinks navigation (reinitializeUI), but the document-level
      // delegated bindings below must only be attached once.
      if (window.studioEvaluationInitialized) return

      window.studioEvaluationInitialized = true;

      const $document = $(document);

      $document.on(
        "change",
        ".js-footer-evaluation-section-toggle-input",
        this.handleToggle.bind(this)
      );
      $document.on(
        "change",
        ".js-footer-evaluation-tab-toggle-input",
        this.handleTabToggle.bind(this)
      );
    },

    handleToggle(event) {
      const checkbox = event.target;
      const wrapper = checkbox.closest(".footer-evaluation-section-toggle");
      const url = wrapper.dataset.toggleUrl;
      const visible = checkbox.checked;
      const payload = {
        phase_id: wrapper.dataset.phaseId,
        section_key: wrapper.dataset.sectionKey,
        visible: visible
      };

      App.Ajax
        .patch(url, payload)
        .then(() => this.onSuccess(checkbox, visible))
        .catch(() => this.onError(checkbox, visible));
    },

    onSuccess(checkbox, visible) {
      const section = checkbox.closest(".phase-evaluation-section");

      section.classList.toggle("-hidden-from-public", !visible);
      section.classList.toggle("js-studio-hide-on-preview", !visible);

      this.updateActiveTabVisibility();
    },

    onError(checkbox, visible) {
      checkbox.checked = !visible;
    },

    handleTabToggle(event) {
      const checkbox = event.target;
      const wrapper = checkbox.closest(".footer-evaluation-tab-toggle");
      const url = wrapper.dataset.toggleUrl;
      const visible = checkbox.checked;
      const payload = {
        phase_id: wrapper.dataset.phaseId,
        tab: wrapper.dataset.tab,
        visible: visible
      };

      App.Ajax
        .patch(url, payload)
        .then(() => this.onTabSuccess(checkbox, wrapper.dataset.tab, visible))
        .catch(() => this.onError(checkbox, visible));
    },

    onTabSuccess(checkbox, tab, visible) {
      this.groupSubnavTabs(tab).forEach((subnavTab) => {
        subnavTab.classList.toggle("-hidden-from-public", !visible);
        subnavTab.classList.toggle("js-studio-hide-on-preview", !visible);
      });

      this.groupContentWrappers(tab).forEach((contentWrapper) => {
        contentWrapper.classList.toggle("js-studio-hide-on-preview", !visible);
      });

      this.syncSectionToggles(checkbox, visible);
    },

    syncSectionToggles(checkbox, visible) {
      const container = checkbox.closest(".projekt-footer-evaluation");
      if (!container) return

      const inputs = container.querySelectorAll(".js-footer-evaluation-section-toggle-input");

      inputs.forEach((input) => {
        input.checked = visible;

        const section = input.closest(".phase-evaluation-section");
        if (!section) return

        section.classList.toggle("-hidden-from-public", !visible);
        section.classList.toggle("js-studio-hide-on-preview", !visible);
      });
    },

    updateActiveTabVisibility() {
      const activeTab = this.activeEvaluationTab();
      if (!activeTab) return

      const anyEnabled = this.toggleableSections().some(
        (section) => !section.classList.contains("-hidden-from-public")
      );

      activeTab.classList.toggle("-hidden-from-public", !anyEnabled);
      activeTab.classList.toggle("js-studio-hide-on-preview", !anyEnabled);

      this.syncTabToggleInput(anyEnabled);
    },

    syncTabToggleInput(anyEnabled) {
      const input = document.querySelector(".js-footer-evaluation-tab-toggle-input");
      if (!input) return

      input.checked = anyEnabled;
    },

    groupSubnavTabs(tab) {
      return Array.from(document.querySelectorAll(
        '.js-projekt-footer-tabs custom-tab[data-visibility-group="' + tab + '"]'
      ));
    },

    groupContentWrappers(tab) {
      return Array.from(document.querySelectorAll(
        '.js-footer-tab-content[data-visibility-group="' + tab + '"]'
      ));
    },

    activeEvaluationTab() {
      return document.querySelector(
        '.js-projekt-footer-tabs custom-tab[for="evaluation"].-active, ' +
        '.js-projekt-footer-tabs custom-tab[for="ai_evaluation"].-active'
      );
    },

    toggleableSections() {
      return Array.from(document.querySelectorAll(".phase-evaluation-section"))
        .filter((section) => section.querySelector(".footer-evaluation-section-toggle"));
    }
  };
}).call(this);

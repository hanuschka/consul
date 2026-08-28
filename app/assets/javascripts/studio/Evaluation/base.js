(function() {
  "use strict";

  App.Studio.Evaluation = {
    initialize() {
      // Window-level flag: this module self-initializes at pack evaluation
      // below (its toggles also exist on poll pages, which are not projekt
      // pages), so it must not double-bind if the pack is evaluated again.
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
        .then((response) => this.onSuccess(wrapper.dataset.sectionKey, visible, response))
        .catch(() => this.onError(checkbox, visible));
    },

    onSuccess(sectionKey, visible, response) {
      this.syncSectionToggleGroup(sectionKey, visible);
      this.applyTabsPublicState(response && response.tabs);
    },

    syncSectionToggleGroup(sectionKey, visible) {
      const wrappers = document.querySelectorAll(
        '.footer-evaluation-section-toggle[data-section-key="' + sectionKey + '"]'
      );

      wrappers.forEach((wrapper) => {
        wrapper.querySelector(".js-footer-evaluation-section-toggle-input").checked = visible;

        const section = wrapper.closest(".phase-evaluation-section");
        if (!section) return

        section.classList.toggle("-hidden-from-public", !visible);
        section.classList.toggle("js-studio-hide-on-preview", !visible);
      });
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
        .then((response) => this.onTabSuccess(checkbox, visible, response))
        .catch(() => this.onError(checkbox, visible));
    },

    onTabSuccess(checkbox, visible, response) {
      this.syncSectionToggles(checkbox, visible);
      this.applyTabsPublicState(response && response.tabs);
    },

    applyTabsPublicState(tabs) {
      if (!tabs) return

      Object.keys(tabs).forEach((tab) => this.applyTabPublicState(tab, tabs[tab]));
      this.syncTabToggleInputs(tabs);
    },

    applyTabPublicState(tab, visible) {
      this.groupSubnavTabs(tab).forEach((subnavTab) => {
        subnavTab.classList.toggle("-hidden-from-public", !visible);
        subnavTab.classList.toggle("js-studio-hide-on-preview", !visible);

        const tooltip = subnavTab.closest("rich-tooltip");
        if (tooltip) tooltip.toggleAttribute("disabled", visible);
      });

      this.groupContentWrappers(tab).forEach((contentWrapper) => {
        contentWrapper.classList.toggle("js-studio-hide-on-preview", !visible);
      });
    },

    syncTabToggleInputs(tabs) {
      const wrappers = document.querySelectorAll(".footer-evaluation-tab-toggle");

      wrappers.forEach((wrapper) => {
        const tab = wrapper.dataset.tab;
        if (!(tab in tabs)) return

        wrapper.querySelector(".js-footer-evaluation-tab-toggle-input").checked = tabs[tab];
      });
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

    groupSubnavTabs(tab) {
      return Array.from(document.querySelectorAll(
        '.js-projekt-footer-tabs custom-tab[data-visibility-group="' + tab + '"], ' +
        '.js-poll-subnav [data-visibility-group="' + tab + '"]'
      ));
    },

    groupContentWrappers(tab) {
      return Array.from(document.querySelectorAll(
        '.js-footer-tab-content[data-visibility-group="' + tab + '"]'
      ));
    }
  };

  App.Studio.Evaluation.initialize();
}).call(this);

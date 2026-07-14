(function() {
  "use strict";

  App.EvaluationVisibilityToggle = {
    initialize() {
      const $document = $(document);

      $document.on(
        "change",
        ".js-footer-evaluation-section-toggle-input",
        this.handleToggle.bind(this)
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

    updateActiveTabVisibility() {
      const activeTab = this.activeEvaluationTab();
      if (!activeTab) return

      const anyEnabled = this.toggleableSections().some(
        (section) => !section.classList.contains("-hidden-from-public")
      );

      activeTab.classList.toggle("-hidden-from-public", !anyEnabled);
      activeTab.classList.toggle("js-studio-hide-on-preview", !anyEnabled);
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

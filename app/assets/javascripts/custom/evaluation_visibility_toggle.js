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
    },

    onError(checkbox, visible) {
      checkbox.checked = !visible;
    }
  };
}).call(this);

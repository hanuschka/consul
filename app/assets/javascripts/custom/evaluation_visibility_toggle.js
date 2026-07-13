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

      this.setStatus(wrapper, "saving");

      App.Ajax
        .patch(url, payload)
        .then(() => this.onSuccess(wrapper, checkbox, visible))
        .catch(() => this.onError(wrapper, checkbox, visible));
    },

    onSuccess(wrapper, checkbox, visible) {
      const section = checkbox.closest(".phase-evaluation-section");

      section.classList.toggle("-hidden-from-public", !visible);
      section.classList.toggle("js-studio-hide-on-preview", !visible);

      this.clearStatus(wrapper);
    },

    onError(wrapper, checkbox, visible) {
      checkbox.checked = !visible;

      this.setStatus(wrapper, "error");
    },

    setStatus(wrapper, state) {
      this.clearStatus(wrapper);
      wrapper.classList.add(`-${state}`);
    },

    clearStatus(wrapper) {
      wrapper.classList.remove("-saving", "-saved", "-error");
    }
  };
}).call(this);

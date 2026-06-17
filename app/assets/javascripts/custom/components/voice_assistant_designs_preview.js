(function() {
  "use strict";

  App.VoiceAssistantDesignsPreview = {
    sessions: null,
    defaultWaveColor: "#97d8ff",

    initialize() {
      const $document = $(document);

      if (!document.querySelector(".js-va-demo")) { return; }

      this.sessions = new WeakMap();

      $document.on("click", ".js-va-demo-toggle", this.handleToggle.bind(this));
      $document.on("click", ".js-va-demo-close", this.handleClose.bind(this));
      $document.on("click", ".js-va-demo-mic", this.handleMic.bind(this));
    },

    handleToggle(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      if (!widget) { return; }

      this.deactivateAll(widget);
      widget.classList.add("-active");
      widget.dataset.state = "active";
      this.startSession(widget);
    },

    handleMic(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      if (!widget) { return; }

      const session = this.sessions.get(widget);

      if (session) {
        session.pauseToggle();
      } else {
        this.startSession(widget);
      }
    },

    handleClose(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      this.deactivate(widget);
    },

    startSession(widget) {
      if (this.sessions.get(widget)) { return; }
      if (typeof App.VoiceAssistantSession === "undefined") { return; }

      const list = widget.closest(".js-va-demo-list");
      const config = list ? list.dataset : {};

      if (App.AssistantUserResourceForm) {
        App.AssistantUserResourceForm.initialize(widget);
      }

      const session = new App.VoiceAssistantSession({
        widget: widget,
        vizContainer: widget.querySelector(".js-va-demo-viz"),
        waveColor: this.getWaveColor(widget),
        createSessionUrl: config.createSessionUrl,
        codename: config.codename,
        projektPhaseId: config.projektPhaseId,
        onStatusChange: (status) => this.handleStatusChange(widget, status),
        onError: (message) => this.handleError(widget, message)
      });

      this.sessions.set(widget, session);
      session.start();
    },

    handleStatusChange(widget, status) {
      widget.dataset.state = status;

      if (status === "running") {
        widget.classList.add("-listening");
      } else if (status === "paused") {
        widget.classList.remove("-listening");
      } else if (status === "initialized") {
        widget.classList.remove("-listening");
        this.sessions.delete(widget);
      }
    },

    handleError(widget, message) {
      widget.classList.remove("-listening");
      console.error("Voice assistant session error:", message);
    },

    deactivate(widget) {
      if (!widget) { return; }

      const session = this.sessions.get(widget);

      if (session) {
        session.stop();
        this.sessions.delete(widget);
      }

      widget.classList.remove("-active");
      widget.classList.remove("-listening");
      widget.dataset.state = "idle";
    },

    deactivateAll(except) {
      const widgets = document.querySelectorAll(".js-va-demo");

      widgets.forEach((widget) => {
        if (widget !== except) {
          this.deactivate(widget);
        }
      });
    },

    getWaveColor(widget) {
      const color = getComputedStyle(widget).getPropertyValue("--va-wave-color").trim();

      return color || this.defaultWaveColor;
    }
  };
}).call(this);

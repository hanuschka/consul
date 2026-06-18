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
      $document.on("click", ".js-va-demo-start", this.handleStart.bind(this));
      $document.on("click", ".js-va-demo-mute", this.handleMute.bind(this));
      $document.on("click", ".js-va-demo-close", this.handleClose.bind(this));
    },

    handleToggle(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      if (!widget) { return; }

      this.deactivateAll(widget);
      widget.classList.add("-active");
      widget.dataset.state = "active";

      this.startSession(widget);
    },

    handleStart(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      if (!widget) { return; }

      this.startSession(widget);
    },

    handleMute(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      if (!widget) { return; }

      const session = this.sessions.get(widget);

      if (session) {
        session.pauseToggle();
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

      if (App.AssistantUserResourceForm && list) {
        App.AssistantUserResourceForm.initialize(list);
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

      const live = status === "starting" || status === "running" || status === "paused";

      widget.classList.toggle("-va-live", live);
      widget.classList.toggle("-listening", status === "running");
      widget.classList.toggle("-va-muted", status === "paused");

      this.updateMuteTooltip(widget, status === "paused" ? "unmute" : "mute");

      if (status === "initialized") {
        this.sessions.delete(widget);
      }
    },

    handleError(widget, message) {
      widget.classList.remove("-listening");
      widget.classList.remove("-va-muted");
      widget.classList.remove("-va-live");
      console.error("Voice assistant session error:", message);
    },

    updateMuteTooltip(widget, kind) {
      const muteButton = widget.querySelector(".js-va-demo-mute");

      if (!muteButton) { return; }

      const text = kind === "unmute" ? muteButton.dataset.unmuteText : muteButton.dataset.muteText;
      muteButton.setAttribute("aria-label", text);

      const tip = widget.querySelector(".voice-assistant-design-mute-tip");

      if (!tip) { return; }

      const body = tip.querySelector(".rich-tooltip--body");

      if (body) {
        body.textContent = text;
      }
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
      widget.classList.remove("-va-muted");
      widget.classList.remove("-va-live");
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

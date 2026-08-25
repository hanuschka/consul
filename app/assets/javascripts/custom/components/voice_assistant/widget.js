(function() {
  "use strict";

  // The EU AI Act notice stays up well past what a slow reader needs, then
  // yields the space once the conversation is under way.
  const NOTICE_VISIBLE_MS = 10000;

  App.VoiceAssistantWidget = {
    sessions: null,
    noticeTimers: null,
    defaultWaveColor: "#97d8ff",

    initialize() {
      const $document = $(document);

      if (!document.querySelector(".js-va-widget")) { return; }

      this.sessions = new WeakMap();
      this.noticeTimers = new WeakMap();

      $document.on("click", ".js-va-toggle", this.handleToggle.bind(this));
      $document.on("click", ".js-va-start", this.handleStart.bind(this));
      $document.on("click", ".js-va-mute", this.handleMute.bind(this));
      $document.on("click", ".js-va-close", this.handleClose.bind(this));
    },

    handleToggle(event) {
      const widget = event.currentTarget.closest(".js-va-widget");

      if (!widget) { return; }

      this.deactivateAll(widget);
      widget.classList.add("-active");
      widget.dataset.state = "active";

      this.startSession(widget);
    },

    handleStart(event) {
      const widget = event.currentTarget.closest(".js-va-widget");

      if (!widget) { return; }

      this.startSession(widget);
    },

    handleMute(event) {
      const widget = event.currentTarget.closest(".js-va-widget");

      if (!widget) { return; }

      const session = this.sessions.get(widget);

      if (session) {
        session.pauseToggle();
      }
    },

    handleClose(event) {
      const widget = event.currentTarget.closest(".js-va-widget");

      this.deactivate(widget);
    },

    startSession(widget) {
      if (this.sessions.get(widget)) { return; }
      if (typeof App.VoiceAssistantSession === "undefined") { return; }

      const container = widget.closest(".js-va-container");
      const config = container ? container.dataset : {};

      if (App.AssistantUserResourceForm && container) {
        App.AssistantUserResourceForm.initialize(container);
      }

      const session = new App.VoiceAssistantSession({
        widget: widget,
        vizContainer: widget.querySelector(".js-va-viz"),
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
      widget.classList.toggle("-va-starting", status === "starting");
      widget.classList.toggle("-listening", status === "running");
      widget.classList.toggle("-va-muted", status === "paused");

      this.updateMuteTooltip(widget, status === "paused" ? "unmute" : "mute");

      if (status === "running") {
        this.scheduleNoticeHide(widget);
      }

      if (status === "initialized") {
        this.sessions.delete(widget);
      }
    },

    scheduleNoticeHide(widget) {
      if (widget.classList.contains("-va-notice-hidden")) { return; }
      if (this.noticeTimers.get(widget)) { return; }

      const timer = setTimeout(() => {
        widget.classList.add("-va-notice-hidden");
        this.noticeTimers.delete(widget);
      }, NOTICE_VISIBLE_MS);

      this.noticeTimers.set(widget, timer);
    },

    cancelNoticeHide(widget) {
      const timer = this.noticeTimers.get(widget);

      if (timer) {
        clearTimeout(timer);
        this.noticeTimers.delete(widget);
      }

      widget.classList.remove("-va-notice-hidden");
    },

    handleError(widget, message) {
      widget.classList.remove("-listening");
      widget.classList.remove("-va-muted");
      widget.classList.remove("-va-live");
      widget.classList.remove("-va-starting");
      console.error("Voice assistant session error:", message);
    },

    updateMuteTooltip(widget, kind) {
      const muteButton = widget.querySelector(".js-va-mute");

      if (!muteButton) { return; }

      const text = kind === "unmute" ? muteButton.dataset.unmuteText : muteButton.dataset.muteText;
      muteButton.setAttribute("aria-label", text);

      const tip = widget.querySelector(".voice-assistant-widget--mute-tip");

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
      widget.classList.remove("-va-starting");
      widget.dataset.state = "idle";

      this.cancelNoticeHide(widget);
    },

    deactivateAll(except) {
      const widgets = document.querySelectorAll(".js-va-widget");

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

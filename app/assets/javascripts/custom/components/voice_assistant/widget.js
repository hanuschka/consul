(function() {
  "use strict";

  // The EU AI Act notice stays up well past what a slow reader needs, then
  // yields the space once the conversation is under way.
  const NOTICE_VISIBLE_MS = 10000;

  // One conversation at a time: deactivateAll closes any other widget before a
  // new one opens, so a single session and a single notice timer are enough.
  App.VoiceAssistantWidget = {
    session: null,
    sessionWidget: null,
    noticeTimer: null,
    defaultWaveColor: "#97d8ff",

    initialize() {
      const $document = $(document);

      if (!document.querySelector(".js-va-widget")) { return; }

      this.session = null;
      this.sessionWidget = null;
      this.noticeTimer = null;

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
      if (this.sessionWidget !== widget) { return; }

      this.session.pauseToggle();
    },

    handleClose(event) {
      const widget = event.currentTarget.closest(".js-va-widget");

      this.deactivate(widget);
    },

    startSession(widget) {
      if (this.sessionWidget === widget) { return; }
      if (typeof App.VoiceAssistantSession === "undefined") { return; }

      const container = widget.closest(".js-va-container");
      const config = container ? container.dataset : {};

      if (App.AssistantUserResourceForm && container) {
        App.AssistantUserResourceForm.initialize(container);
      }

      this.session = new App.VoiceAssistantSession({
        widget: widget,
        vizContainer: widget.querySelector(".js-va-viz"),
        waveColor: this.getWaveColor(widget),
        createSessionUrl: config.createSessionUrl,
        codename: config.codename,
        projektPhaseId: config.projektPhaseId,
        onStatusChange: (status) => this.handleStatusChange(widget, status),
        onError: (message) => this.handleError(widget, message)
      });
      this.sessionWidget = widget;

      this.session.start();
    },

    forgetSession(widget) {
      if (this.sessionWidget !== widget) { return; }

      this.session = null;
      this.sessionWidget = null;
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
        widget.classList.add("-va-notice-shown");
        this.scheduleNoticeHide(widget);
      }

      if (status === "initialized") {
        this.forgetSession(widget);
      }
    },

    scheduleNoticeHide(widget) {
      if (widget.classList.contains("-va-notice-hidden")) { return; }
      if (this.noticeTimer) { return; }

      this.noticeTimer = setTimeout(() => {
        widget.classList.add("-va-notice-hidden");
        this.noticeTimer = null;
      }, NOTICE_VISIBLE_MS);
    },

    resetNotice(widget) {
      if (this.noticeTimer) {
        clearTimeout(this.noticeTimer);
        this.noticeTimer = null;
      }

      widget.classList.remove("-va-notice-shown");
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

      if (this.sessionWidget === widget) {
        this.session.stop();
        this.forgetSession(widget);
      }

      widget.classList.remove("-active");
      widget.classList.remove("-listening");
      widget.classList.remove("-va-muted");
      widget.classList.remove("-va-live");
      widget.classList.remove("-va-starting");
      widget.dataset.state = "idle";

      this.resetNotice(widget);
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

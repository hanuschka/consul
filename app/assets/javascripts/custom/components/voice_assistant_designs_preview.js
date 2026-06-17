(function() {
  "use strict";

  App.VoiceAssistantDesignsPreview = {
    waveMap: null,
    defaultWaveColor: "#3f78e0",

    initialize() {
      const $document = $(document);

      if (!document.querySelector(".js-va-demo")) { return; }

      this.waveMap = new WeakMap();

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
      this.startWave(widget, false);
    },

    handleClose(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      this.deactivate(widget);
    },

    handleMic(event) {
      const widget = event.currentTarget.closest(".js-va-demo");

      if (!widget) { return; }

      const isListening = widget.classList.toggle("-listening");
      widget.dataset.state = isListening ? "listening" : "active";
      this.setWaveListening(widget, isListening);
    },

    deactivate(widget) {
      if (!widget) { return; }

      widget.classList.remove("-active");
      widget.classList.remove("-listening");
      widget.dataset.state = "idle";
      this.stopWave(widget);
    },

    deactivateAll(except) {
      const widgets = document.querySelectorAll(".js-va-demo");

      widgets.forEach((widget) => {
        if (widget !== except) {
          this.deactivate(widget);
        }
      });
    },

    startWave(widget, listening) {
      const container = widget.querySelector(".js-va-demo-viz");

      if (!container) { return; }
      if (typeof SiriWave === "undefined") { return; }

      this.stopWave(widget);

      const wave = new SiriWave({
        container: container,
        width: container.clientWidth || 240,
        height: container.clientHeight || 40,
        style: "ios",
        color: this.getWaveColor(widget),
        speed: listening ? 0.2 : 0.1,
        amplitude: listening ? 1.3 : 0.35,
        autostart: true
      });

      this.waveMap.set(widget, wave);
    },

    setWaveListening(widget, listening) {
      const wave = this.waveMap.get(widget);

      if (!wave) {
        this.startWave(widget, listening);
        return;
      }

      wave.setAmplitude(listening ? 1.3 : 0.35);
      wave.setSpeed(listening ? 0.2 : 0.1);
    },

    stopWave(widget) {
      const wave = this.waveMap.get(widget);

      if (wave) {
        wave.stop();
        this.waveMap.delete(widget);
      }

      const container = widget.querySelector(".js-va-demo-viz");

      if (container) {
        container.innerHTML = "";
      }
    },

    getWaveColor(widget) {
      const color = getComputedStyle(widget).getPropertyValue("--va-wave-color").trim();

      return color || this.defaultWaveColor;
    }
  };
}).call(this);

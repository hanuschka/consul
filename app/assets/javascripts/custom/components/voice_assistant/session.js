(function() {
  "use strict";

  const STATUSES = {
    initialized: "initialized",
    starting: "starting",
    stoping: "stoping",
    paused: "paused",
    running: "running"
  };

  class VoiceAssistantSession {
    constructor(options) {
      this.options = options;
      this.status = STATUSES.initialized;
      this.rtcPeerConnection = null;
      this.currentMicrophoneTrack = null;
      this.mediaStream = null;
      this.dataChannel = null;
      this.audioEl = null;
      this.wave = null;
      this.greetingResponseId = null;
      this.urlParams = new URLSearchParams(window.location.search);
    }

    async start() {
      try {
        this.setStatus(STATUSES.starting);

        if (this.urlParams.get("dont_start_voice_session") === "true") {
          setTimeout(() => {
            this.setStatus(STATUSES.running);
            this.setupWave();
          }, 1500);
          return;
        }

        // Run the WebRTC setup (mic capture + offer) and the ephemeral-session
        // request concurrently — they don't depend on each other — to cut the
        // time-to-connect roughly to the slower of the two instead of their sum.
        const results = await Promise.all([this.setupConnection(), this.requestSession()]);
        const session = results[1];

        await this.connectToOpenai(session.ephemeral_key, session.model);
      } catch (error) {
        console.error("Failed to initialize connection:", error);
        this.cleanupConnection();
        this.setStatus(STATUSES.initialized);
        this.showError(this.errorMessageFor(error));
      }
    }

    async setupConnection() {
      this.rtcPeerConnection = new RTCPeerConnection();

      this.audioEl = document.createElement("audio");
      this.audioEl.autoplay = true;

      this.rtcPeerConnection.ontrack = this.handleRtcPeerConnectionTrack.bind(this);

      await this.startAudioRecordingAndAttachToRtcConnection(this.rtcPeerConnection);

      this.dataChannel = this.rtcPeerConnection.createDataChannel("oai-events");
      this.dataChannel.addEventListener("message", this.handleRtcDataChannelMessage.bind(this));
      this.dataChannel.onopen = this.handleDataChannelOpen.bind(this);
      this.dataChannel.onclose = this.handleDataChannelClose.bind(this);

      const offer = await this.rtcPeerConnection.createOffer();
      await this.rtcPeerConnection.setLocalDescription(offer);
    }

    requestSession() {
      const payload = { codename: this.options.codename };

      if (this.options.projektPhaseId) {
        payload.consul_projekt_phase_id = this.options.projektPhaseId;
      }

      return App.Ajax.post(this.options.createSessionUrl, payload);
    }

    async connectToOpenai(ephemeralKey, model) {
      const answer = await this.startOpenaiVoiceSession(ephemeralKey, model);

      await this.rtcPeerConnection.setRemoteDescription(answer);
    }

    async startOpenaiVoiceSession(ephemeralKey, model) {
      const body = new FormData();
      body.set("sdp", this.rtcPeerConnection.localDescription.sdp);
      body.set("session", JSON.stringify({ type: "realtime", model: model }));

      const sdpResponse = await fetch("https://api.openai.com/v1/realtime/calls", {
        method: "POST",
        body: body,
        headers: {
          Authorization: `Bearer ${ephemeralKey}`
        }
      });

      if (!sdpResponse.ok) {
        const errorBody = await sdpResponse.text();
        throw new Error(`OpenAI realtime call failed (${sdpResponse.status}): ${errorBody}`);
      }

      return {
        type: "answer",
        sdp: await sdpResponse.text()
      };
    }

    async startAudioRecordingAndAttachToRtcConnection(rtcPeerConnection) {
      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });
      this.currentMicrophoneTrack = this.mediaStream.getTracks()[0];
      rtcPeerConnection.addTrack(this.currentMicrophoneTrack);
    }

    pauseToggle() {
      if (this.status === STATUSES.running) {
        if (this.currentMicrophoneTrack) {
          this.currentMicrophoneTrack.enabled = false;
        }
        this.setStatus(STATUSES.paused);
      } else if (this.status === STATUSES.paused) {
        if (this.currentMicrophoneTrack) {
          this.currentMicrophoneTrack.enabled = true;
        }
        this.setStatus(STATUSES.running);
      }
    }

    stop() {
      const doneMessage = {
        type: "response.create",
        response: {
          output_modalities: ["audio"],
          instructions: "Der Nutzer ist fertig. Erstelle jetzt Titel und Beschreibung und antworte ausschließlich auf Deutsch."
        }
      };

      if (this.dataChannel) {
        this.dataChannel.send(JSON.stringify(doneMessage));
      }

      this.stopRtcConnection();
      this.stopMicrophone();
      this.teardownWave();
    }

    stopMicrophone() {
      if (this.mediaStream) {
        this.mediaStream.getTracks().forEach((track) => { track.stop(); });
      }
    }

    stopRtcConnection() {
      this.setStatus(STATUSES.stoping);

      setTimeout(() => {
        if (this.dataChannel) {
          this.dataChannel.close();
          this.rtcPeerConnection.close();
        }
        this.setStatus(STATUSES.initialized);
      }, 100);
    }

    handleDataChannelOpen() {
      this.setStatus(STATUSES.running);
      this.setupWave();
      this.sendGreeting();
    }

    handleDataChannelClose() {
      this.setStatus(STATUSES.initialized);
      this.dataChannel = null;
    }

    sendGreeting() {
      this.greetingResponseId = null;
      this.dataChannel.send(JSON.stringify({ type: "response.create" }));
    }

    enableServerVad() {
      if (!this.dataChannel || this.dataChannel.readyState !== "open") { return; }

      this.dataChannel.send(JSON.stringify({
        type: "session.update",
        session: {
          type: "realtime",
          audio: {
            input: {
              turn_detection: {
                type: "server_vad",
                threshold: 0.5,
                prefix_padding_ms: 300,
                silence_duration_ms: 500,
                create_response: true,
                interrupt_response: true
              }
            }
          }
        }
      }));
    }

    handleRtcPeerConnectionTrack(e) {
      const stream = e.streams[0];
      this.audioEl.srcObject = stream;

      if (e.track.kind === "audio") {
        this.animateAudioTrack(stream);
      }
    }

    animateAudioTrack(stream) {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)();
      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();

      source.connect(analyser);
      analyser.fftSize = 256;

      const dataArray = new Uint8Array(analyser.frequencyBinCount);

      const animate = () => {
        analyser.getByteTimeDomainData(dataArray);

        let sum = 0;
        for (let i = 0; i < dataArray.length; i++) {
          sum += Math.abs(dataArray[i] - 128);
        }

        if (this.wave) {
          this.wave.setAmplitude(sum / dataArray.length / 8);
        }

        requestAnimationFrame(animate);
      };

      animate();
    }

    handleRtcDataChannelMessage(e) {
      try {
        const message = JSON.parse(e.data);

        if (message.type === "error") {
          console.error("Voice assistant realtime error:", message.error);
        }

        if (message.type === "response.created" && !this.greetingResponseId) {
          this.greetingResponseId = message.response && message.response.id;
        }

        if (this.isGreetingAudioDone(message)) {
          this.greetingResponseId = null;
          this.enableServerVad();
        }

        if (message.response && message.response.status === "failed") {
          console.error("Error in connection:", message.response.status_details.error);
        }

        if (message.type === "response.function_call_arguments.done" && App.AssistantUserResourceForm) {
          App.AssistantUserResourceForm.handleFunctionCall(message);
        }
      } catch (error) {
        console.error("Error parsing WebRTC message:", error);
      }
    }

    isGreetingAudioDone(message) {
      const isAudioDoneEvent =
        message.type === "response.output_audio.done"
        || message.type === "output_audio_buffer.stopped";

      return isAudioDoneEvent
        && this.greetingResponseId
        && message.response_id === this.greetingResponseId;
    }

    setupWave() {
      const container = this.options.vizContainer;

      if (!container) { return; }
      if (typeof SiriWave === "undefined") { return; }

      this.teardownWave();

      this.wave = new SiriWave({
        container: container,
        width: container.clientWidth || 240,
        height: container.clientHeight || 40,
        style: "ios",
        color: this.options.waveColor || "#97d8ff",
        speed: 0.2,
        amplitude: 0.3,
        autostart: true
      });
    }

    teardownWave() {
      if (this.wave) {
        this.wave.stop();
        this.wave = null;
      }

      if (this.options.vizContainer) {
        this.options.vizContainer.innerHTML = "";
      }
    }

    setStatus(newStatus) {
      this.status = newStatus;

      if (this.options.onStatusChange) {
        this.options.onStatusChange(newStatus);
      }
    }

    cleanupConnection() {
      this.stopMicrophone();

      if (this.dataChannel) {
        this.dataChannel.close();
        this.dataChannel = null;
      }

      if (this.rtcPeerConnection) {
        this.rtcPeerConnection.close();
        this.rtcPeerConnection = null;
      }
    }

    errorMessageFor(error) {
      const micErrorNames = ["NotAllowedError", "NotFoundError", "SecurityError"];

      if (error && micErrorNames.indexOf(error.name) !== -1) {
        return "Mikrofon-Zugriff nicht möglich. Bitte Browser-Berechtigungen prüfen.";
      }

      return "Verbindung zum Sprachassistenten fehlgeschlagen. Bitte erneut versuchen.";
    }

    showError(message) {
      if (this.options.onError) {
        this.options.onError(message);
      }
    }
  }

  App.VoiceAssistantSession = VoiceAssistantSession;
}).call(this);

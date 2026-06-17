(function() {
  "use strict";

  const STATUSES = {
    initialized: "initialized",
    starting: "starting",
    stoping: "stoping",
    paused: "paused",
    running: "running"
  };

  App.VoiceAssistantSession = function(options) {
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
  };

  App.VoiceAssistantSession.statuses = STATUSES;

  App.VoiceAssistantSession.prototype = {
    start: async function() {
      try {
        this.setStatus(STATUSES.starting);

        if (this.urlParams.get("dont_start_voice_session") === "true") {
          setTimeout(() => {
            this.setStatus(STATUSES.running);
            this.setupWave();
          }, 1500);
          return;
        }

        await this.requestSession();
      } catch (error) {
        console.error("Failed to initialize connection:", error);
        this.setStatus(STATUSES.initialized);
        this.showError("Mikrofon-Zugriff nicht möglich. Bitte Browser-Berechtigungen prüfen.");
      }
    },

    requestSession: async function() {
      const payload = { codename: this.options.codename };

      if (this.options.projektPhaseId) {
        payload.consul_projekt_phase_id = this.options.projektPhaseId;
      }

      const response = await App.Ajax.post(this.options.createSessionUrl, payload);

      await this.handleSessionInitialized(response.ephemeral_key, response.model);
    },

    handleSessionInitialized: async function(ephemeralKey, model) {
      this.rtcPeerConnection = new RTCPeerConnection();

      this.audioEl = document.createElement("audio");
      this.audioEl.autoplay = true;

      this.rtcPeerConnection.ontrack = this.handleRtcPeerConnectionTrack.bind(this);

      await this.startAudioRecordingAndAttachToRtcConnection(this.rtcPeerConnection);

      const dataChannel = this.rtcPeerConnection.createDataChannel("oai-events");
      const offer = await this.rtcPeerConnection.createOffer();
      await this.rtcPeerConnection.setLocalDescription(offer);

      await this.waitForIceGatheringComplete();

      const answer = await this.startOpenaiVoiceSession(ephemeralKey, model);
      await this.rtcPeerConnection.setRemoteDescription(answer);

      this.dataChannel = dataChannel;
      this.dataChannel.addEventListener("message", this.handleRtcDataChannelMessage.bind(this));
      this.dataChannel.onopen = this.handleDataChannelOpen.bind(this);
      this.dataChannel.onclose = this.handleDataChannelClose.bind(this);
    },

    waitForIceGatheringComplete: function() {
      const pc = this.rtcPeerConnection;

      if (pc.iceGatheringState === "complete") {
        return Promise.resolve();
      }

      return new Promise((resolve) => {
        const checkState = function() {
          if (pc.iceGatheringState === "complete") {
            pc.removeEventListener("icegatheringstatechange", checkState);
            resolve();
          }
        };

        pc.addEventListener("icegatheringstatechange", checkState);

        setTimeout(() => {
          pc.removeEventListener("icegatheringstatechange", checkState);
          resolve();
        }, 5000);
      });
    },

    startOpenaiVoiceSession: async function(ephemeralKey, model) {
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

      return {
        type: "answer",
        sdp: await sdpResponse.text()
      };
    },

    startAudioRecordingAndAttachToRtcConnection: async function(rtcPeerConnection) {
      this.mediaStream = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true
        }
      });
      this.currentMicrophoneTrack = this.mediaStream.getTracks()[0];
      rtcPeerConnection.addTrack(this.currentMicrophoneTrack);
    },

    pauseToggle: function() {
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
    },

    stop: function() {
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
    },

    stopMicrophone: function() {
      if (this.mediaStream) {
        this.mediaStream.getTracks().forEach((track) => { track.stop(); });
      }
    },

    stopRtcConnection: function() {
      this.setStatus(STATUSES.stoping);

      setTimeout(() => {
        if (this.dataChannel) {
          this.dataChannel.close();
          this.rtcPeerConnection.close();
        }
        this.setStatus(STATUSES.initialized);
      }, 100);
    },

    handleDataChannelOpen: function() {
      this.setStatus(STATUSES.running);
      this.setupWave();
      this.sendGreeting();
    },

    handleDataChannelClose: function() {
      this.setStatus(STATUSES.initialized);
      this.dataChannel = null;
    },

    sendGreeting: function() {
      this.greetingResponseId = null;
      this.dataChannel.send(JSON.stringify({ type: "response.create" }));
    },

    enableServerVad: function() {
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
    },

    handleRtcPeerConnectionTrack: function(e) {
      const stream = e.streams[0];
      this.audioEl.srcObject = stream;

      if (e.track.kind === "audio") {
        this.animateAudioTrack(stream);
      }
    },

    animateAudioTrack: function(stream) {
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
    },

    handleRtcDataChannelMessage: function(e) {
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

        if (message.type === "response.function_call_arguments.done") {
          this.handleAssistantFunctionCall(message);
        }
      } catch (error) {
        console.error("Error parsing WebRTC message:", error);
      }
    },

    isGreetingAudioDone: function(message) {
      const isAudioDoneEvent =
        message.type === "response.output_audio.done"
        || message.type === "output_audio_buffer.stopped";

      return isAudioDoneEvent
        && this.greetingResponseId
        && message.response_id === this.greetingResponseId;
    },

    handleAssistantFunctionCall: function(message) {
      const form = App.AssistantUserResourceForm;

      if (!form) { return; }
      if (!document.querySelector(".js-user-resources-form")) { return; }

      const args = JSON.parse(message.arguments);

      switch (message.name) {
        case "createResource":
        case "createProposal":
        case "createBudgetInvestment":
        case "createDeficiencyReport":
          this.handleResourceCreate(args);
          break;
        case "updateTitle":
          form.updateTitle(args.value);
          break;
        case "updateDescription":
          form.updateDescription(args.value);
          break;
        case "selectLabels":
          form.toggleLabels(args.label_ids, true, true);
          break;
        case "deselectLabels":
          form.toggleLabels(args.label_ids, false, true);
          break;
        case "selectSentiment":
          form.selectSentiment(args.sentiment_id, true);
          break;
        case "updateLocation":
          form.updateLocation(args.location, true);
          break;
        case "generateImage":
          form.generateImage(args.image_prompt);
          break;
        case "selectCategory":
          form.selectCategory(args.category_id);
          break;
        case "selectImplementationPerformer":
          form.selectImplementationPerformer(args.implementation_performer, true);
          break;
        case "updateImplementaionContribution":
          form.updateImplementaionContribution(args.implementaion_contribution, true);
          break;
        case "updateUserCostEstimate":
          form.updateUserCostEstimate(args.user_cost_estimate, true);
          break;
      }
    },

    handleResourceCreate: function(args) {
      const form = App.AssistantUserResourceForm;

      if (args.title) { form.updateTitle(args.title); }
      if (args.description) { form.updateDescription(args.description); }
      if (args.image_prompt) { form.generateImage(args.image_prompt); }
      if (args.selected_label_ids) { form.toggleLabels(args.selected_label_ids, true); }
      if (args.deselected_label_ids) { form.toggleLabels(args.deselected_label_ids, false); }
      if (args.sentiment_id) { form.selectSentiment(args.sentiment_id); }
      if (args.location) { form.updateLocation(args.location); }
      if (args.category_id) { form.selectCategory(args.category_id); }
      if (args.implementation_performer) { form.selectImplementationPerformer(args.implementation_performer); }
      if (args.implementaion_contribution) { form.updateImplementaionContribution(args.implementaion_contribution); }
      if (args.user_cost_estimate) { form.updateUserCostEstimate(args.user_cost_estimate); }
    },

    setupWave: function() {
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
    },

    teardownWave: function() {
      if (this.wave) {
        this.wave.stop();
        this.wave = null;
      }

      if (this.options.vizContainer) {
        this.options.vizContainer.innerHTML = "";
      }
    },

    setStatus: function(newStatus) {
      this.status = newStatus;

      if (this.options.onStatusChange) {
        this.options.onStatusChange(newStatus);
      }
    },

    showError: function(message) {
      if (this.options.onError) {
        this.options.onError(message);
      }
    }
  };
}).call(this);

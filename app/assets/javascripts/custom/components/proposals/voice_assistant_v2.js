(function() {
  "use strict";

  App.VoiceAssistantV2 = {
    element: null,
    status: "not_initialized",
    initialData: null,
    urlParams: null,
    rtcPeerConnection: null,
    currentMicrophoneTrack: null,
    mediaStream: null,
    dataChannel: null,
    audioEl: null,
    wave: null,

    statuses: {
      not_initialized: "not_initialized",
      initialized: "initialized",
      starting: "starting",
      stoping: "stoping",
      paused: "paused",
      running: "running"
    },

    initialize: function() {
      const element = document.querySelector(".js-voice-assistant");

      if (!element) { return; }
      if (element.dataset.version !== "v2") { return; }

      this.element = element;
      this.status = "not_initialized";
      this.initialData = null;
      this.rtcPeerConnection = null;
      this.currentMicrophoneTrack = null;
      this.mediaStream = null;
      this.dataChannel = null;
      this.audioEl = null;
      this.wave = null;
      this.greetingResponseId = null;
      this.urlParams = new URLSearchParams(window.location.search);

      this.getCollapseButton().addEventListener("click", this.collapseAssistant.bind(this));
      this.getExpandButton().addEventListener("click", this.expandAssistant.bind(this));
      this.getSpeakButton().addEventListener("click", this.toggleAssistant.bind(this));
      this.getStopButton().addEventListener("click", this.stopAssistant.bind(this));
      this.getSpeakButton().addEventListener("animationend", this.toggleButtonAnimationEnd.bind(this));

      window.addEventListener("beforeunload", this.handleTabClose.bind(this));

      this.setInitialData(JSON.parse(element.dataset.initialData));
    },

    setInitialData: function(data) {
      if (this.status === this.statuses.initialized) {
        return;
      }

      this.initialData = data;
      this.setStatus(this.statuses.initialized);
      App.AssistantUserResourceForm.initialize(this.element);

      if (this.initialData.collapsible) {
        this.getCollapseButton().style.display = "flex";
        this.isCollapsed = this.initialData.collapsed;
        this.initCollapseState();
      }

      this.element.classList.add("-initialized");
      this.setupSiriWave();
    },

    initCollapseState: function() {
      this.element.classList.toggle("-collapsed", this.isCollapsed);
    },

    toggleAssistantCollapseState: function(collapsed) {
      App.Cookies.saveCookie("voice_assistant_collapsed", collapsed, 365);
    },

    collapseAssistant: function() {
      this.isCollapsed = true;
      this.element.classList.add("-collapsed");
      this.stopAssistant();
      this.toggleAssistantCollapseState(true);
    },

    expandAssistant: function() {
      this.isCollapsed = false;
      this.element.classList.remove("-collapsed");
      this.toggleAssistantCollapseState(false);
    },

    toggleAssistant: function() {
      if (this.status === this.statuses.initialized) {
        this.startAssistant();
      } else if (this.status === this.statuses.running) {
        this.pauseAssistant();
      } else if (this.status === this.statuses.paused) {
        this.unpauseAssistant();
      }
    },

    startAssistant: async function() {
      try {
        this.setStatus(this.statuses.starting);

        if (this.urlParams.get("dont_start_voice_session") === "true") {
          setTimeout(function() {
            App.VoiceAssistantV2.setStatus(App.VoiceAssistantV2.statuses.running);
          }, 1500);
          return;
        }

        await this.requestSession();
      } catch (error) {
        console.error("Failed to initialize connection:", error);
        this.setStatus(this.statuses.initialized);
        this.showError("Mikrofon-Zugriff nicht möglich. Bitte Browser-Berechtigungen prüfen.");
      }
    },

    requestSession: async function() {
      const dataset = this.element.dataset;
      const payload = { codename: dataset.codename };

      if (dataset.projektPhaseId) {
        payload.consul_projekt_phase_id = dataset.projektPhaseId;
      }

      const response = await App.Ajax.post(dataset.createSessionUrl, payload);

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

      return new Promise(function(resolve) {
        const checkState = function() {
          if (pc.iceGatheringState === "complete") {
            pc.removeEventListener("icegatheringstatechange", checkState);
            resolve();
          }
        };

        pc.addEventListener("icegatheringstatechange", checkState);

        setTimeout(function() {
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

    pauseAssistant: function() {
      if (this.currentMicrophoneTrack) {
        this.currentMicrophoneTrack.enabled = false;
      }
      this.setStatus(this.statuses.paused);
    },

    unpauseAssistant: function() {
      if (this.status === this.statuses.paused) {
        if (this.currentMicrophoneTrack) {
          this.currentMicrophoneTrack.enabled = true;
        }
        this.setStatus(this.statuses.running);
      }
    },

    stopAssistant: function() {
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
    },

    stopMicrophone: function() {
      if (this.mediaStream) {
        this.mediaStream.getTracks().forEach(function(track) { track.stop(); });
      }
    },

    stopRtcConnection: function() {
      this.setStatus(this.statuses.stoping);

      setTimeout(function() {
        if (App.VoiceAssistantV2.dataChannel) {
          App.VoiceAssistantV2.dataChannel.close();
          App.VoiceAssistantV2.rtcPeerConnection.close();
        }
        App.VoiceAssistantV2.setStatus(App.VoiceAssistantV2.statuses.initialized);
      }, 100);
    },

    handleDataChannelOpen: function() {
      this.setStatus(this.statuses.running);
      this.sendGreeting();
    },

    handleDataChannelClose: function() {
      this.setStatus(this.statuses.initialized);
      this.dataChannel = null;
    },

    handleTabClose: function() {},

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

      const animate = function() {
        analyser.getByteTimeDomainData(dataArray);

        let sum = 0;
        for (let i = 0; i < dataArray.length; i++) {
          sum += Math.abs(dataArray[i] - 128);
        }

        if (App.VoiceAssistantV2.wave) {
          App.VoiceAssistantV2.wave.setAmplitude(sum / dataArray.length / 8);
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
      const args = JSON.parse(message.arguments);
      const form = App.AssistantUserResourceForm;

      switch (message.name) {
        case "createResource":
          this.handleResourceCreate(args);
          break;
        case "createProposal":
          this.handleResourceCreate(args);
          break;
        case "createBudgetInvestment":
          this.handleResourceCreate(args);
          break;
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

    setStatus: function(newStatus) {
      this.status = newStatus;
      this.element.dataset.status = newStatus;

      const speakButton = this.getSpeakButton();

      if (newStatus === this.statuses.starting) {
        speakButton.disabled = true;
      } else if (newStatus === this.statuses.initialized) {
        speakButton.disabled = false;
        this.getMessagebar().classList.remove("-visible");
      }

      speakButton.title = this.getSpeakButtonTitle();
    },

    getSpeakButtonTitle: function() {
      const dataset = this.getSpeakButton().dataset;

      if (this.status === this.statuses.running) {
        return dataset.titleMute;
      } else if (this.status === this.statuses.paused) {
        return dataset.titleUnmute;
      } else if (this.status === this.statuses.initialized) {
        return dataset.titleStart;
      } else if (this.status === this.statuses.starting) {
        return dataset.titleLoading;
      }
    },

    toggleButtonAnimationEnd: function() {
      this.getSpeakButton().disabled = false;
    },

    setupSiriWave: function() {
      this.wave = new SiriWave({
        container: this.element.querySelector(".js-voice-assistant-visualization"),
        speed: 0.2,
        color: "#97d8ff",
        amplitude: 0.3
      });
    },

    getSpeakButton: function() {
      return this.element.querySelector(".js-voice-assistant-speak-button");
    },

    getStopButton: function() {
      return this.element.querySelector(".js-voice-assistant-stop-button");
    },

    getCollapseButton: function() {
      return this.element.querySelector(".js-voice-assistant-collapse-button");
    },

    getExpandButton: function() {
      return this.element.querySelector(".js-voice-assistant-expand-button");
    },

    showError: function(message) {
      const messagebar = this.getMessagebar();
      messagebar.innerHTML = message;
      messagebar.title = message;
      messagebar.classList.add("-error");
      messagebar.classList.add("-visible");
    },

    getMessagebar: function() {
      return this.element.querySelector(".js-voice-assistant-messagebar");
    }
  };


}).call(this);

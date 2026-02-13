(function() {
  "use strict";

  App.VoiceAssistant = {
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

      this.element = element;
      this.status = "not_initialized";
      this.initialData = null;
      this.rtcPeerConnection = null;
      this.currentMicrophoneTrack = null;
      this.mediaStream = null;
      this.dataChannel = null;
      this.audioEl = null;
      this.wave = null;
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
            App.VoiceAssistant.setStatus(App.VoiceAssistant.statuses.running);
          }, 1500);
          return;
        }

        await this.requestSession();
      } catch (error) {
        console.error("Failed to initialize connection:", error);
      }
    },

    requestSession: async function() {
      const dataset = this.element.dataset;
      const response = await App.Ajax.post(dataset.createSessionUrl, {
        codename: dataset.codename,
        consul_projekt_phase_id: dataset.projektPhaseId
      });

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

      const answer = await this.startOpenaiVoiceSession(ephemeralKey, offer, model);
      await this.rtcPeerConnection.setRemoteDescription(answer);

      this.dataChannel = dataChannel;
      this.dataChannel.addEventListener("message", this.handleRtcDataChannelMessage.bind(this));
      this.dataChannel.onopen = this.handleDataChannelOpen.bind(this);
      this.dataChannel.onclose = this.handleDataChannelClose.bind(this);
    },

    startOpenaiVoiceSession: async function(ephemeralKey, offer, model) {
      const baseUrl = "https://api.openai.com/v1/realtime";

      const sdpResponse = await fetch(`${baseUrl}?model=${model}`, {
        method: "POST",
        body: offer.sdp,
        headers: {
          Authorization: `Bearer ${ephemeralKey}`,
          "Content-Type": "application/sdp"
        }
      });

      return {
        type: "answer",
        sdp: await sdpResponse.text()
      };
    },

    startAudioRecordingAndAttachToRtcConnection: async function(rtcPeerConnection) {
      this.mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
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
          modalities: ["text", "audio"],
          instructions: "I'm done. Generate title and description."
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
        if (App.VoiceAssistant.dataChannel) {
          App.VoiceAssistant.dataChannel.close();
          App.VoiceAssistant.rtcPeerConnection.close();
        }
        App.VoiceAssistant.setStatus(App.VoiceAssistant.statuses.initialized);
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
      const language = this.element.dataset.language;
      const greetingText =
        language === "en" ? "Hi" : "Hallo";

      const greetingMessage = {
        type: "response.create",
        response: {
          modalities: ["text", "audio"],
          instructions: greetingText
        }
      };

      const greetingDelay = parseInt(this.urlParams.get("greeting_delay")) || 350;

      setTimeout(function() {
        App.VoiceAssistant.dataChannel.send(JSON.stringify(greetingMessage));
      }, greetingDelay);
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

        if (App.VoiceAssistant.wave) {
          App.VoiceAssistant.wave.setAmplitude(sum / dataArray.length / 8);
        }

        requestAnimationFrame(animate);
      };

      animate();
    },

    handleRtcDataChannelMessage: function(e) {
      try {
        const message = JSON.parse(e.data);

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
      // this.waveDecoration = new SiriWave({
      //   container: this.element.querySelector(".js-voice-assistant-visualization-blur"),
      //   speed: 0.05,
      //   color: "#97d8ff",
      //   amplitude: 0.3
      // });
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

    getMessagebar: function() {
      return this.element.querySelector(".js-voice-assistant-messagebar");
    }
  };


}).call(this);

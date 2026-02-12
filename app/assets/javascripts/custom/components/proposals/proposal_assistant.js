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
      const searchParams = new URLSearchParams(window.location.search);
      const dataset = this.element.dataset;

      const response = await App.Ajax.request({
        method: "POST",
        url: dataset.createSessionUrl,
        data: {
          codename: dataset.codename,
          consul_projekt_phase_id: searchParams.get("consul_projekt_phase_id"),
          data: this.initialData
        }
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
        language === "en" ? "Let's start." : "Lasst uns beginnen.";

      const greetingMessage = {
        type: "response.create",
        response: {
          modalities: ["text", "audio"],
          instructions: greetingText
        }
      };

      const greetingDelay = parseInt(this.urlParams.get("greeting_delay")) || 100;

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

      switch (message.name) {
        case "generateResource":
          this.handleGenerateResource(args);
          break;
        case "updateTitle":
          this.updateTitle(args.value);
          break;
        case "updateDescription":
          this.updateDescription(args.value);
          break;
        case "selectLabels":
          this.toggleLabels(args.label_ids, true, true);
          break;
        case "deselectLabels":
          this.toggleLabels(args.label_ids, false, true);
          break;
        case "selectSentiment":
          this.selectSentiment(args.sentiment_id, true);
          break;
        case "updateLocation":
          this.updateLocation(args.location, true);
          break;
        case "generateImage":
          this.generateImage(args.image_prompt);
          break;
        case "selectCategory":
          this.selectCategory(args.category_id);
          break;
        case "selectImplementationPerformer":
          this.selectImplementationPerformer(args.implementation_performer, true);
          break;
        case "updateImplementaionContribution":
          this.updateImplementaionContribution(args.implementaion_contribution, true);
          break;
        case "updateUserCostEstimate":
          this.updateUserCostEstimate(args.user_cost_estimate, true);
          break;
      }
    },

    handleGenerateResource: function(args) {
      if (args.title) { this.updateTitle(args.title); }
      if (args.description) { this.updateDescription(args.description); }
      if (args.image_prompt) { this.generateImage(args.image_prompt); }
      if (args.selected_label_ids) { this.toggleLabels(args.selected_label_ids, true); }
      if (args.deselected_label_ids) { this.toggleLabels(args.deselected_label_ids, false); }
      if (args.sentiment_id) { this.selectSentiment(args.sentiment_id); }
      if (args.location) { this.updateLocation(args.location); }
      if (args.category_id) { this.selectCategory(args.category_id); }
      if (args.implementation_performer) { this.selectImplementationPerformer(args.implementation_performer); }
      if (args.implementaion_contribution) { this.updateImplementaionContribution(args.implementaion_contribution); }
      if (args.user_cost_estimate) { this.updateUserCostEstimate(args.user_cost_estimate); }
    },

    updateLocation: function(locationName, shouldScroll) {
      const messagebar = this.getMessagebar();
      messagebar.classList.remove("-visible");

      App.Ajax.request({
        method: "GET",
        url: this.element.dataset.geocodeUrl,
        data: { location_name: locationName }
      })
      .then(function(locationJson) {
        messagebar.classList.remove("-error");
        messagebar.innerHTML = "";

        if (locationJson.coordinates) {
          App.VoiceAssistant.updateMapLocation(locationJson.coordinates, shouldScroll);
        }

        messagebar.classList.add("-visible");
      })
      .catch(function() {
        const message = `Die Adresse ${locationName} ist mir nicht bekannt.`;
        messagebar.innerHTML = message;
        messagebar.title = message;
        messagebar.classList.add("-error");
        messagebar.classList.add("-visible");
      });
    },

    generateImage: function(prompt) {
      this.showImageGeneratingAnimation();

      const searchParams = new URLSearchParams(window.location.search);
      const dataset = this.element.dataset;

      setTimeout(function() {
        App.Ajax.request({
          method: "POST",
          url: dataset.generateImageUrl,
          data: {
            prompt: prompt,
            codename: dataset.codename,
            consul_projekt_phase_id: searchParams.get("consul_projekt_phase_id")
          }
        })
        .then(function(imageData) {
          App.VoiceAssistant.updateImage(imageData.image);
        });
      }, 3000);
    },

    updateTitle: function(title, scroll) {
      var scroll = scroll || true;
      var titleElement = $(".js-user-resource-form-title:visible").get(0);

      $(".js-user-resource-form-title").val(title);

      if (scroll) {
        titleElement.scrollIntoView({ block: "center", inline: "nearest" });
      }

      var bannerElement = document.querySelector(".user-resources-form--banner-editor");
      this.addChangedFieldsHighlightTo(bannerElement);
    },

    updateDescription: function(description, scroll) {
      var scroll = scroll || true;
      var editor = App.HTMLEditor.instances["userResourceFromEditor"];
      editor.setData(description);

      if (scroll) {
        editor.sourceElement.scrollIntoView({ block: "center", inline: "nearest" });
      }

      var editorContent = document.querySelector(".ck-content.ck-editor__editable");
      this.addChangedFieldsHighlightTo(editorContent);
    },

    selectCategory: function(categoryId, shouldScroll) {
      var categorySelectElement = document.querySelector(".js-user-resource-select-category");
      categorySelectElement.value = categoryId;
      this.highlightAndScrollToContentCard(categorySelectElement, shouldScroll);
    },

    selectImplementationPerformer: function(implementationPerformer, shouldScroll) {
      var implementationPerformerElement = document.querySelector(".js-implementation-performer-select");
      implementationPerformerElement.value = implementationPerformer;
      implementationPerformerElement.dispatchEvent(new Event("change", { bubbles: true }));
      this.highlightAndScrollToContentCard(implementationPerformerElement, shouldScroll);
    },

    updateImplementaionContribution: function(implementationContribution, shouldScroll) {
      var implementationContributionElement = document.querySelector(".js-budget-implementation-contribution");
      implementationContributionElement.value = implementationContribution;
      this.highlightAndScrollToContentCard(implementationContributionElement, shouldScroll);
    },

    updateUserCostEstimate: function(userCostEstimate, shouldScroll) {
      var userCostEstimateElement = document.querySelector(".js-budget-user-cost-estimate-field");
      userCostEstimateElement.value = userCostEstimate;
      this.highlightAndScrollToContentCard(userCostEstimateElement, shouldScroll);
    },

    toggleLabels: function(labelIds, checked, shouldScroll) {
      if (labelIds && labelIds.length > 0) {
        var recentLabelElements;

        labelIds.forEach(function(labelId) {
          recentLabelElements = document.querySelectorAll(".js-projekt-label[data-label-id='" + labelId + "']");
          recentLabelElements.forEach(function(labelElement) {
            labelElement.click();
          });
        });

        this.highlightAndScrollToContentCard(Array.from(recentLabelElements)[0], shouldScroll);
      }
    },

    selectSentiment: function(sentimentId, shouldScroll) {
      if (sentimentId) {
        var sentimentElement = document.querySelector(".js-projekt-phase-sentiment[data-sentiment-id='" + sentimentId + "']");
        sentimentElement.click();
        this.highlightAndScrollToContentCard(sentimentElement, shouldScroll);
      }
    },

    updateMapLocation: function(coordinates, shouldScroll) {
      if (App.Mapbox.maps.length > 0) {
        var currentMapInstance = App.Mapbox.maps[0];

        if (currentMapInstance && App.Mapbox.maps.length <= 1) {
          currentMapInstance.map.jumpTo({
            center: [coordinates[1], coordinates[0]],
            duration: 1000
          });

          currentMapInstance.moveOrPlaceMarker({
            lngLat: {
              lng: coordinates[1],
              lat: coordinates[0]
            }
          });

          if (shouldScroll) {
            currentMapInstance.map.getContainer().scrollIntoView({
              block: "center", inline: "nearest"
            });
          }
        }
      } else if (App.Map.maps.length > 0) {
        App.Map.setMarkerTo(coordinates[0], coordinates[1], false);
      }
    },

    updateImage: function(image) {
      var imageFileInput = document.querySelector(".js-direct-image-upload--input");
      setBase64ToFileInput(imageFileInput, image);
    },

    showImageGeneratingAnimation: function() {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(true);
    },

    highlightAndScrollToContentCard: function(element, shouldScroll) {
      var section = element.closest(".js-sidebar-card");

      if (section) {
        this.addChangedFieldsHighlightTo(section);
        if (shouldScroll) {
          section.scrollIntoView({ block: "center", inline: "nearest" });
        }
      }
    },

    addChangedFieldsHighlightTo: function(element) {
      element.classList.add("assistant-changed-field-highlight");

      setTimeout(function() {
        element.classList.remove("assistant-changed-field-highlight");
      }, 2500);
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

    getMessagebar: function() {
      return this.element.querySelector(".js-voice-assistant-messagebar");
    }
  };

  function setBase64ToFileInput(fileInput, base64String) {
    const byteCharacters = atob(base64String);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
      byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    const byteArray = new Uint8Array(byteNumbers);
    const blob = new Blob([byteArray], { type: "image/jpeg" });
    const file = new File([blob], "generated_image.jpg", { type: "image/jpeg" });
    const dataTransfer = new DataTransfer();
    dataTransfer.items.add(file);
    fileInput.files = dataTransfer.files;
    fileInput.dispatchEvent(new Event("change"));
  }
}).call(this);

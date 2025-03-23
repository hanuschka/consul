(function() {
  "use strict";

  App.ProposalAssistant = {
    initialized: false,
    initialize: function() {
      this.voiceAssistantIframe = document.querySelector(".js-voice-assistant-iframe")

      if (this.voiceAssistantIframe) {
        window.addEventListener('message', this.handleGlobalMessage.bind(this));
        this.initialData = JSON.parse(this.voiceAssistantIframe.dataset.initialData);

        this.initialized = true

        // console.log("iframe.contentDocument.readyState", this.voiceAssistantIframe.contentDocument.readyState)
        if (this.voiceAssistantIframe.contentDocument && this.voiceAssistantIframe.contentDocument.readyState === "complete") {
          this.tryToPushInitialDataToDtAssistant();
        }
        else {
          this.voiceAssistantIframe.addEventListener("load", function() {
            this.tryToPushInitialDataToDtAssistant();
          })
        }
        this.tryToPushInitialDataToDtAssistant();
      }
    },

    handleGlobalMessage: function(event) {
      if (event.data) {
        const data = parseIframeEventData(event.data);
        const params = data.params

        // console.log("CONSUL handleGlobalMessage", data.event_type, data.params)

        switch(data.event_type) {
          case "Consul.callbacks.VoiceAssistant.connected":
            this.tryToPushInitialDataToDtAssistant();
            break;
          case "Consul.VoiceAssistant.turnedOn":
            this.expandAssistantIframe();
            break;
          case "Consul.resourceForm.updateTitle":
            this.updateProposalTitle(params.value);
            break;
          case "Consul.resourceForm.updateDescription":
            this.updateProposalDescription(params.value);
            break;
          case "Consul.resourceForm.updateDescription":
            this.updateProposalDescription(params.value);
            break;
          case "Consul.resourceForm.selectLabels":
            this.toggleLabels(params.label_ids, true)
            break;
          case "Consul.resourceForm.deselectLabels":
            this.toggleLabels(params.label_ids, false)
            break;
          case "Consul.resourceForm.selectSentiment":
            this.selectSentiment(params.sentiment_id)
            break;
          case "Consul.ResourceForm.updateMapLocation":
            this.updateMapLocation(params.coordinates)
            break;
        }
      }
    },

    tryToPushInitialDataToDtAssistant: function() {
      console.log("Consul: push initialData for DT", this.initialData)

      this.postMessageToDtIframe(
        "Dt.VoiceAssistant.loadInitialData", this.initialData
      )
    },

    expandAssistantIframe: function() {
      this.voiceAssistantIframe.classList.add("-running")
    },

    highlightBanner: function() {
     var bannerElement = document.querySelector(".user-resources-form--banner-editor")

      bannerElement.classList.add("assistant-changed-field-highlight-transition")
      bannerElement.classList.add("assistant-changed-field-highlight")

      setTimeout(function() {
        bannerElement.classList.remove("assistant-changed-field-highlight")
      }, 3000)
      setTimeout(function() {
        bannerElement.classList.remove("assistant-changed-field-highlight-transition")
      }, 5500)
    },

    updateProposal: function(params) {
      this.updateProposalTitle(params.title, false)
      this.updateProposalDescription(params.description, false)
    },

    updateProposalTitle: function(title, scroll) {
      var scroll = scroll || true;

      var titleElement = document.querySelector(
        ".js-user-resource-form-title"
      )

      titleElement.value = title

      if (scroll) {
        titleElement.scrollIntoView({block: "center", inline: "nearest"})
      }

      this.highlightBanner()
    },

    updateProposalDescription: function(description, scroll) {
      var scroll = scroll || true;

      var editor = window.CKeditorInstancesGlobal["proposal_translations_attributes_0_description"]
      editor.setData(description)

      if (scroll) {
        editor.sourceElement.scrollIntoView({block: "center", inline: "nearest"})
      }

      var editorContent = document.querySelector(".ck-content.ck-editor__editable")

      editorContent.classList.add("assistant-changed-field-highlight-transition")
      editorContent.classList.add("assistant-changed-field-highlight")

      setTimeout(function() {
        editorContent.classList.remove("assistant-changed-field-highlight")
      }, 3000)
      setTimeout(function() {
        editorContent.classList.remove("assistant-changed-field-highlight-transition")
      }, 3500)
    },


    toggleLabels: function(labelIds, checked) {
      labelIds.forEach(function(labelId) {
        var labelElements = document.querySelectorAll(".js-projekt-label[data-label-id='" + labelId + "']");

        labelElements.forEach(function(labelElement) {
          // labelElement.control.checked = checked;
          labelElement.click()
        })
      })
    },

    selectSentiment: function(sentimentId) {
      var selector = ".js-projekt-phase-sentiment[data-sentiment-id='" + sentimentId + "']";
      var sentimentElement = document.querySelector(selector);

      // sentimentElement.control.checked = true;
      sentimentElement.click()
    },

    updateMapLocation: function(coordinates) {
      var currentMap = App.Map.maps[0]

      if (currentMap && App.Map.maps.length <= 1) {
        currentMap.panTo(new L.LatLng(coordinates[0], coordinates[1]));
        App.Map.lastMapSetMarkerTo(coordinates[0], coordinates[1])
      }
    },

    postMessageToDtIframe(eventType, params) {
      this.voiceAssistantIframe.contentWindow.postMessage(
        JSON.stringify({
          event_type: eventType,
          params
        }),
        '*'
      );
    }
  };


  function parseIframeEventData(eventData) {
    if (typeof eventData === "string") {
      return JSON.parse(eventData)
    } else if (typeof eventData === "object"){
      return eventData
    }
  }
}).call(this);

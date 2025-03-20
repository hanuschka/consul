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
      }
    },

    handleGlobalMessage: function(event) {
      if (event.data) {
        const data = parseIframeEventData(event.data);
        const params = data.params

        // console.log("CONSUL handleGlobalMessage", data.event_type, data.params)

        switch(data.event_type) {
          case "Consul.callbacks.VoiceAssistant.loaded":
            this.loadInitialDataForAssistant();
            break;
          case "Consul.ProposalForm.updateTitle":
            this.updateProposalTitle(params.value);
            break;
          case "Consul.ProposalForm.updateDescription":
            this.updateProposalDescription(params.value);
            break;
          case "Consul.ProposalForm.updateDescription":
            this.updateProposalDescription(params.value);
            break;
          case "Consul.ProposalForm.selectLabels":
            this.toggleLabels(params.label_ids, true)
            break;
          case "Consul.ProposalForm.deselectLabels":
            this.toggleLabels(params.label_ids, false)
            break;
          case "Consul.ProposalForm.selectSentiment":
            this.selectSentiment(params.sentiment_id)
            break;

        }
      }
    },

    loadInitialDataForAssistant: function() {
      this.postMessageToDtIframe(
        "Dt.VoiceAssistant.loadInitialData", this.initialData
      )
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

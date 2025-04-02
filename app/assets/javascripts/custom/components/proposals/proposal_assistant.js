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

        console.log("CONSUL handleGlobalMessage", data.event_type, data.params)

        switch(data.event_type) {
          case "Consul.callbacks.VoiceAssistant.connected":
            this.tryToPushInitialDataToDtAssistant();
            break;
          case "Consul.VoiceAssistant.turnedOn":
            this.expandAssistantIframe();
            break;
          case "Consul.ResourceForm.updateTitle":
            this.updateTitle(params.value);
            break;
          case "Consul.ResourceForm.updateDescription":
            this.updateDescription(params.value);
            break;
          case "Consul.ResourceForm.selectLabels":
            this.toggleLabels(params.label_ids, true, params.shouldScroll)
            break;
          case "Consul.ResourceForm.deselectLabels":
            this.toggleLabels(params.label_ids, false, params.shouldScroll)
            break;
          case "Consul.ResourceForm.selectSentiment":
            this.selectSentiment(params.sentiment_id, params.shouldScroll)
            break;
          case "Consul.ResourceForm.updateImage":
            this.updateImage(params.image)
            break;
          case "Consul.ResourceForm.selectCategory":
            this.selectCategory(params.categoryId)
            break;
          case "Consul.ResourceForm.updateLocation":
            this.updateMapLocation(
              params.coordinates, params.shouldScroll
            )
            break;
          case "Consul.ResourceForm.showImageGeneratingAnimation":
            this.showImageGeneratingAnimation()
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

    updateProposal: function(params) {
      this.updateTitle(params.title, false)
      this.updateDescription(params.description, false)
    },

    updateTitle: function(title, scroll) {
      var scroll = scroll || true;

      var titleElement = document.querySelector(
        ".js-user-resource-form-title"
      )

      titleElement.value = title

      if (scroll) {
        titleElement.scrollIntoView({block: "center", inline: "nearest"})
      }

      var bannerElement = document.querySelector(".user-resources-form--banner-editor")

      this.addChangedFieldsHighlightTo(bannerElement)
    },

    updateDescription: function(description, scroll) {
      var scroll = scroll || true;

      var editor = window.CKeditorInstancesGlobal["userResourceFromEditor"]
      editor.setData(description)

      if (scroll) {
        editor.sourceElement.scrollIntoView({block: "center", inline: "nearest"})
      }

      var editorContent = document.querySelector(".ck-content.ck-editor__editable")

      this.addChangedFieldsHighlightTo(editorContent)
    },

    selectCategory(categoryId, shouldScroll) {
      var categorySelectElement = document.querySelector(".js-user-resource-select-category")

      categorySelectElement.value = categoryId

      this.highlightAndScrollToContentCard(categorySelectElement, shouldScroll)
    },

    toggleLabels: function(labelIds, checked, shouldScroll) {
      if (labelIds && labelIds.length > 0) {
        var recentLabelElements;

        labelIds.forEach(function(labelId) {
          recentLabelElements = document.querySelectorAll(".js-projekt-label[data-label-id='" + labelId + "']");

          recentLabelElements.forEach(function(labelElement) {
            // labelElement.control.checked = checked;
            labelElement.click()
          })
        })

        this.highlightAndScrollToContentCard(Array.from(recentLabelElements)[0], shouldScroll)
      }
    },

    selectSentiment: function(sentimentId, shouldScroll) {
      if (sentimentId) {
        var selector = ".js-projekt-phase-sentiment[data-sentiment-id='" + sentimentId + "']";
        var sentimentElement = document.querySelector(selector);

        sentimentElement.click()

        this.highlightAndScrollToContentCard(sentimentElement, shouldScroll)
      }
    },

    updateMapLocation: function(coordinates, shouldScroll) {
      var currentMap = App.Map.maps[0]

      if (currentMap && App.Map.maps.length <= 1) {
        currentMap.panTo(new L.LatLng(coordinates[0], coordinates[1]));
        App.Map.lastMapSetMarkerTo(coordinates[0], coordinates[1])

        if (shouldScroll) {
          currentMap.getContainer().scrollIntoView({
            block: "center", inline: "nearest"
          })
        }
      }
    },

    updateImage: function(image) {
      var imageFileInput = document.querySelector(".js-direct-image-upload--input")

      setBase64ToFileInput(imageFileInput, image)
    },

    showImageGeneratingAnimation: function() {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(true)
    },

    highlightAndScrollToContentCard: function(element, shouldScroll) {
      var section = element.closest(".js-sidebar-card")

      if (section) {
        this.addChangedFieldsHighlightTo(section)
        if (shouldScroll) {
          section.scrollIntoView({
            block: "center", inline: "nearest"
          })
        }
      }
    },

    addChangedFieldsHighlightTo: function(element) {
      element.classList.add("assistant-changed-field-highlight")

      setTimeout(function() {
        element.classList.remove("assistant-changed-field-highlight")
      }, 2500)
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
    fileInput.dispatchEvent(new Event('change'));
  }

  function parseIframeEventData(eventData) {
    if (typeof eventData === "string") {
      return JSON.parse(eventData)
    } else if (typeof eventData === "object"){
      return eventData
    }
  }
}).call(this);

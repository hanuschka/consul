(function() {
  "use strict";

  App.ProposalAssistant = {
    initialized: false,
    initialize: function() {


      window.addEventListener('message', this.handleGlobalMessage.bind(this));
      this.initialized = true
    },

    handleGlobalMessage: function(event) {
      console.log("handleGlobalMessage")
      console.log(event)
      if (event.data) {
        const data = parseIframeEventData(event.data);
        const params = data.params

        switch(data.event_type) {
          case "Consul.ProposalForm.updateTitle":
            this.updateProposalTitle(params.value);
            break;
          case "Consul.ProposalForm.updateDescription":
            this.updateProposalDescription(params.value);
            break;
        }
      }
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
      }, 3500)
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

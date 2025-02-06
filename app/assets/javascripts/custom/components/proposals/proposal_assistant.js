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

    updateProposalTitle: function(title) {
      const titleElement = document.querySelector(
        ".js-user-resource-form-title"
      )

      titleElement.value = title
      titleElement.scrollIntoView({block: "center", inline: "nearest"})
    },

    updateProposalDescription: function(description) {
      var editor = window.CKeditorInstancesGlobal["proposal_translations_attributes_0_description"]
      editor.setData(description)
      editor.sourceElement.scrollIntoView({block: "center", inline: "nearest"})
      // console.log(editor)
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

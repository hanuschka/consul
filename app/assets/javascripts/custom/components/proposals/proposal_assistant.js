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
          case "Consul.ProposalForm.updateField":
            this.updateProposalField(params);
            break;
        }
      }
    },

    updateProposalField: function(params) {
      switch(params.field) {
        case "title":
          this.updateProposalTitle(params.value);
          break;
        case "title":
          this.updateProposalDescription(params.value);
          break;
      }
    },

    updateProposalTitle: function(title) {
      document.querySelector(
        ".js-user-resource-form-title"
      ).value = title
    },

    updateProposalDescription: function(description) {
      window.CKeditorInstancesGlobal["proposal_translations_attributes_0_description"].setData(description)
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

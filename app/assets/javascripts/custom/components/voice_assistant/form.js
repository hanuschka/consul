(function() {
  "use strict";

  App.AssistantUserResourceForm = {
    element: null,

    initialize: function(element) {
      this.element = element;
    },

    handleFunctionCall: function(message) {
      if (!document.querySelector(".js-user-resource-form-title")) { return; }

      const args = JSON.parse(message.arguments);

      switch (message.name) {
        case "createResource":
        case "createProposal":
        case "createBudgetInvestment":
        case "createDeficiencyReport":
          this.handleResourceCreate(args);
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

    handleResourceCreate: function(args) {
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

      setTimeout(App.AssistantUserResourceForm.refreshMaps, 200);
    },

    selectCategory: function(categoryId, shouldScroll) {
      var categorySelectElement = document.querySelector(".js-user-resource-select-category");

      if (!categorySelectElement) return;

      categorySelectElement.value = categoryId;
      categorySelectElement.dispatchEvent(new Event("change", { bubbles: true }));
      this.highlightAndScrollToContentCard(categorySelectElement, shouldScroll);
    },

    updateLocation: function(locationName, shouldScroll) {
      const messagebar = this.getMessagebar();
      messagebar.classList.remove("-visible");

      App.Ajax
        .get(this.element.dataset.geocodeUrl, { location_name: locationName })
        .then(function(locationJson) {
          messagebar.classList.remove("-error");
          messagebar.innerHTML = "";

          if (locationJson.coordinates) {
            App.AssistantUserResourceForm.updateMapLocation(locationJson.coordinates, shouldScroll);
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

    updateMapLocation: function(coordinates, shouldScroll) {
      this.refreshMaps();

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

      setTimeout(App.AssistantUserResourceForm.refreshMaps, 300);
    },

    updateImage: function(image) {
      var imageFileInput = $(".js-direct-image-upload:visible")
        .first()
        .find(".js-direct-image-upload--input")
        .get(0);

      setBase64ToFileInput(imageFileInput, image);
    },

    showImageGeneratingAnimation: function() {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(true);
    },

    generateImage: function(prompt) {
      this.showImageGeneratingAnimation();

      const dataset = this.element.dataset;

      setTimeout(() => {
        App.Ajax
          .post(dataset.generateImageUrl, {
            prompt: prompt,
            aspect_ratio: dataset.aspectRatio,
            codename: dataset.codename,
            consul_projekt_phase_id: dataset.projektPhaseId
          })
          .then((imageData) => {
            App.AssistantUserResourceForm.updateImage(imageData.image);
          })
          .catch((request) => {
            App.AssistantUserResourceForm.hideImageGeneratingAnimation();
            App.AssistantUserResourceForm.showImageError(
              request.responseJSON && request.responseJSON.error
            );
          });
      }, 100);
    },

    hideImageGeneratingAnimation: function() {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(false);
    },

    showImageError: function(message) {
      const messagebar = this.getMessagebar();

      if (!messagebar || !message) return;

      messagebar.innerHTML = message;
      messagebar.title = message;
      messagebar.classList.add("-error");
      messagebar.classList.add("-visible");
    },

    toggleLabels: function(labelIds, checked, shouldScroll) {
      if (!labelIds || labelIds.length === 0) return;

      var lastLabelElement;

      labelIds.forEach(function(labelId) {
        var labelElements = document.querySelectorAll(".js-projekt-label[data-label-id='" + labelId + "']");

        labelElements.forEach(function(labelElement) {
          var checkbox = document.getElementById(labelElement.htmlFor);

          if (checkbox.checked !== checked) {
            labelElement.click();
          }

          lastLabelElement = labelElement;
        });
      });

      if (lastLabelElement) {
        this.highlightAndScrollToContentCard(lastLabelElement, shouldScroll);
      }
    },

    selectSentiment: function(sentimentId, shouldScroll) {
      if (sentimentId) {
        var sentimentElement = document.querySelector(".js-projekt-phase-sentiment[data-sentiment-id='" + sentimentId + "']");
        sentimentElement.click();
        this.highlightAndScrollToContentCard(sentimentElement, shouldScroll);
      }
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

    getMessagebar: function() {
      return document.querySelector(".js-voice-assistant-messagebar");
    },

    refreshMaps: function() {
      App.Map.maps.forEach(function(mapInstance) {
        var map = mapInstance.map;

        if (!map) return;

        if (typeof map.resize === "function") {
          map.resize();
        } else if (typeof map.invalidateSize === "function") {
          map.invalidateSize();
        }
      });
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
    $(fileInput).trigger("change");
  }
}).call(this);

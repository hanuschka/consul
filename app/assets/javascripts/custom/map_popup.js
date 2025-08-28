App.MapPopup = {
  excludedProcesses: ["proposal", "deficiency_report", "idea", "projekt", "point_of_interest_pin"],

  generatePopupContent: function(data, resourceType) {
    if (resourceType == "proposal") {
      return this.standardResourcePopupContent(data, resourceType);
    } else if (resourceType == "deficiency_report") {
      return this.standardResourcePopupContent(data, resourceType);
    } else if (resourceType == "idea") {
      return this.standardResourcePopupContent(data, resourceType);
    } else if (resourceType == "projekt") {
      return this.standardResourcePopupContent(data, resourceType);
    } else if (resourceType == "point_of_interest_pin") {
      return this.pointOfInterestPopupContent(data);
    } else {
      return this.standardResourcePopupContent(data, resourceType);
    }
  },

  getPopupDataUrl: function(resourceType, properties) {
    // console.log("getPopupDataUrl", resourceType, properties)
    if (resourceType == "proposal") {
      return "/proposals/" + properties.id + "/json_data";
    } else if (resourceType == "deficiency_report") {
      return "/deficiency_reports/" + properties.id + "/json_data";
    } else if (resourceType == "idea") {
      return "/ideas/" + properties.id + "/json_data";
    } else if (resourceType == "projekt") {
      return "/projekts/" + properties.id + "/json_data";
    } else if (resourceType == "investment") {
      return "/investments/" + properties.id + "/json_data";
    } else if (resourceType == "point_of_interest_pin") {
      return "/projekt_point_of_interest_pins/" + properties.id + "/json_data?projekt_phase_id=" + properties.projekt_phase_id;
    }
  },

  getResourceUrl: function(data, resourceType) {
    switch(resourceType)  {
      case  "proposal":
        return "/proposals/" + data.id
      case  "deficiency_report":
        return "/deficiency_reports/" + data.id;
      case  "idea":
        return "/ideas/" + data.id;
      case "projekt":
        return "/projekts/" + data.id;
      case "investment":
        return "/budgets/" + data.budget_id + "/investments/" + data.id;
    }
  },

  standardResourcePopupContent: function(data, resourceType) {
    var url = this.getResourceUrl(data, resourceType)

    if (data.projekt_phase_id) {
      url += "?projekt_phase_id=" + data.projekt_phase_id;
    }

    var popupHtml;

    if (url && url.length > 0) {
      popupHtml = "<h5><a href='" + url + "'>" + data.title + "</a></h5>"; //title
    }
    else {
      popupHtml = "<h5>" + data.title + "</h5>"; //title
    }

    if (data.image_url) {
      popupHtml += "<img class='resource-map-popup-image' src='" + data.image_url + "' </img>"; //image
    }

    if ((data.labels || data.sentiments) && (data.labels.length || Object.keys(data.sentiment).length)) {
      popupHtml += "<div class='resource-map-popup-details resource-taggings'>";

      if (data.labels.length) {
        var labels = "<div class='projekt-labels'>";
        data.labels.forEach(function(label) {
          labels += "<span class='projekt-label selected'>"
          labels += "<i class='fas fa-" + label.icon + "' style='margin-right:4px;'></i>"
          labels += label.name
          labels += "</span>";
        });
        labels += "</div>";
        popupHtml += labels;
      }

      if (Object.keys(data.sentiment).length) {
        var sentiments = "<div class='sentiments'>";
        sentiments += "<span class='sentiment' style='background-color:" + data.sentiment.backgroundColor + ";color:" + data.sentiment.color + "'>" + data.sentiment.name + "</span>";
        sentiments += "</div>";
        popupHtml += sentiments;
      }

      popupHtml += "</div>";
    }
    popupHtml = "<div class='proposal-map-popup-content'>" + popupHtml + "</div>"

    return popupHtml;
  },

  pointOfInterestPopupContent: function(data) {
    // console.log("pointOfInterestPopupContent", data)
    var popupHtml = "<h5 style='color:" + data.category.color + "'>";
    popupHtml += "<i style='margin-right: 7px' class='icon-" + data.category.icon + "'></i>"
    popupHtml += data.category.name;
    popupHtml += "</h5>";

    return popupHtml;
  },

}

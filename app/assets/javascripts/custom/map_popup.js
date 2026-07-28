App.MapPopup = {
  excludedProcesses: ["proposal", "deficiency_report", "idea", "projekt", "projekt_point_of_interest_pin"],

  generatePopupContent: function(data, resourceType, properties, hasMasterportalContext) {
    if (resourceType == "proposal") {
      return this.standardResourcePopupContent(data, resourceType, hasMasterportalContext);
    } else if (resourceType == "deficiency_report") {
      return this.standardResourcePopupContent(data, resourceType, hasMasterportalContext);
    } else if (resourceType == "idea") {
      return this.standardResourcePopupContent(data, resourceType, hasMasterportalContext);
    } else if (resourceType == "projekt") {
      return this.standardResourcePopupContent(data, resourceType, hasMasterportalContext);
    } else if (resourceType == "projekt_point_of_interest_pin") {
      return this.pointOfInterestPopupContent(data, properties);
    } else if (resourceType == "masterportal_pin") {
      return this.masterportalPinPopupContent(data, hasMasterportalContext);
    } else {
      return this.standardResourcePopupContent(data, resourceType, hasMasterportalContext);
    }
  },

  sourceCaption: function(isMasterportal) {
    var text = isMasterportal ? "Masterportal-Pin" : "Nutzerbeitrag";

    return "<div class='map-popup--source-caption'>" + text + "</div>";
  },

  getPopupDataUrl: function(resourceType, properties) {
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
    } else if (resourceType == "projekt_point_of_interest_pin") {
      return "/projekt_point_of_interest_pins/" + properties.id + "/json_data";
    } else if (resourceType == "masterportal_pin") {
      return "/masterportal_pins/" + properties.id + "/json_data";
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

  standardResourcePopupContent: function(data, resourceType, hasMasterportalContext) {
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

    if (hasMasterportalContext) {
      popupHtml += this.sourceCaption(false);
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

  pointOfInterestPopupContent: function(data, properties) {
    var popupHtml = "<h5 style='color:" + properties.feature_color + "'>";
    popupHtml += "<i style='margin-right: 7px' class='icon-" + properties.feature_icon_name + "'></i>"
    popupHtml += properties.feature_category_name || "Point of Interest";
    popupHtml += "</h5>";

    return popupHtml;
  },

  masterportalPinPopupContent: function(data, hasMasterportalContext) {
    var headerHtml = this.masterportalPinHeader(data);
    var rowsHtml = (data.popup_data || []).map(this.masterportalPinRow.bind(this)).join("");

    var html = "<div class='masterportal-popup'>";
    html += headerHtml;

    if (hasMasterportalContext) {
      html += this.sourceCaption(true);
    }

    if (rowsHtml) {
      html += "<dl class='masterportal-popup--rows'>" + rowsHtml + "</dl>";
    }

    html += "</div>";

    return html;
  },

  masterportalPinHeader: function(data) {
    var titleText = data.associated_resource_title || data.title || "";
    if (!titleText) return "";

    var safeTitle = this.escapeHtml(titleText);

    if (data.associated_resource_url) {
      return "<h5 class='masterportal-popup--title'>" +
             "<a href='" + this.escapeHtml(data.associated_resource_url) + "'>" + safeTitle + "</a>" +
             "</h5>";
    }

    return "<h5 class='masterportal-popup--title'>" + safeTitle + "</h5>";
  },

  masterportalPinRow: function(row) {
    var label = this.escapeHtml(row.label || "");
    var value = row.value == null ? "" : String(row.value);
    var valueHtml = this.masterportalPinValue(row.type, value);

    return "<dt class='masterportal-popup--row-label'>" + label + "</dt>" +
           "<dd class='masterportal-popup--row-value'>" + valueHtml + "</dd>";
  },

  masterportalPinValue: function(type, value) {
    var safe = this.escapeHtml(value);

    if (type === "email") return "<a href='mailto:" + safe + "'>" + safe + "</a>";
    if (type === "url") return "<a href='" + safe + "' target='_blank' rel='noopener noreferrer'>" + safe + "</a>";
    if (type === "phone") return "<a href='tel:" + safe + "'>" + safe + "</a>";

    return safe;
  },

  escapeHtml: function(value) {
    var div = document.createElement("div");
    div.textContent = value == null ? "" : String(value);
    return div.innerHTML;
  }
}

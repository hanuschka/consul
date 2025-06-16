App.MapPopup = {
  getPopupContent: function(data, resourceName) {
    console.log("getPopupContent", data, resourceName)

    if (resourceName == "proposals" || data.proposal_id) {
      return this.proposalPopupContent(data);

    } else if ( resourceName == "deficiency-reports" ) {
      return this.deficiencyReportPopupContent(data);

    } else if ( resourceName == "projekts" ) {
      return this.projektPopupContent(data);

    } else if ( resourceName == "point-of-interest-pin" ) {

      return this.pointOfInterestPopupContent(data);
    } else {
      return this.budgetsPopupContent(data);
    }

  },

  proposalPopupContent: function(data) {
    console.log("proposalPopupContent", data)

    var proposalUrl = "/proposals/" + data.proposal_id;
    if (data.projekt_phase_id) {
      proposalUrl += "?projekt_phase_id=" + data.projekt_phase_id;
    }

    var popupHtml;
    popupHtml = "<h5><a href='" + proposalUrl + "'>" + data.proposal_title + "</a></h5>"; //title

    if (data.image_url) {
      popupHtml += "<img class='resource-map-popup-image' src='" + data.image_url + "' </img>"; //image
    }

    if (data.labels.length || Object.keys(data.sentiment).length) {
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

  deficiencyReportPopupContent: function(data) {
    var popupHtml = "";
    popupHtml += "<h5><a href='/deficiency_reports/" + data.deficiency_report_id + "'>" + data.deficiency_report_title + "</a></h5>";

    if (data.image_url) {
      popupHtml += "<img class='resource-map-popup-image' src='" + data.image_url + "' </img>"; //image
    }

    return popupHtml;
  },

  budgetsPopupContent: function(data) {
    var popupHtml = "";
    popupHtml += "<h5><a href='/budgets/" + data.budget_id + "/investments/" + data.investment_id + "'>" + data.investment_title + "</a></h5>";

    if (data.image_url) {
      popupHtml += "<img class='resource-map-popup-image' src='" + data.image_url + "' </img>"; //image
    }

    return popupHtml;
  },

  pointOfInterestPopupContent: function(data) {
    var popupHtml = "<h5 style='color:" + data.category.color + "'>";
    popupHtml += "<i style='margin-right: 7px' class='icon-" + data.category.icon + "'></i>"
    popupHtml += data.category.name;
    popupHtml += "</h5>";

    return popupHtml;
  },

  projektPopupContent: function(data) {
    // return "<a href='/projekts/" + data.projekt_id + "'>" + data.projekt_title + "</a>";
    var popupHtml = "";
    popupHtml += "<h5 style=';word-wrap:break-word;'><a href='/projekts/" + data.projekt_id + "'>" + data.projekt_title + "</a></h5>"; //title

    if (data.image_url) {
      popupHtml += "<img class='resource-map-popup-image' src='" + data.image_url + "' >"; //image
    }

    if (data.sdg_goals.length || data.tags.length ) {
      popupHtml += "<div class='resource-map-popup-details'>";

      if (data.sdg_goals && data.sdg_goals.length) {
        var sdg_goals = "<div class='projekt-sdg-goals'>";
        data.sdg_goals.forEach(function(sdg_goal) {
          sdg_goals += "<span class='projekt-sdg-goal'>"
          sdg_goals += "<img title='" + sdg_goal.title + "' src='" + sdg_goal.image + "' style='width:35px;margin-right:4px;margin-bottom:4px;'></i>"
          sdg_goals += "</span>";
        });
        sdg_goals += "</div>";
        popupHtml += sdg_goals;
      }

      if (data.tags && data.tags.length) {
        var tags = "<div class='tags'>";
        data.tags.forEach(function(tag) {
          tags += "<span class='tag' style='font-size:0.75rem;padding:0.33333rem 0.5rem;margin-bottom:4px;'>" + tag + "</span>";
        });
        tags += "</div>";

        popupHtml += tags;
      }

      popupHtml += "</div>";
    }

    return popupHtml;
  }
}

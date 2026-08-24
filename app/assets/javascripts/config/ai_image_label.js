(function() {
  "use strict";

  window.App = window.App || {};

  // The one JS copy of Shared::AiImageLabelComponent's markup, for the two
  // places that assemble image HTML client-side: the Mapbox popup content and
  // the studio banner uploader. Wording and icon are passed in from the server
  // so nothing here has to know the locale or the asset digest. Styling comes
  // from the main-app pack (custom_new_design/components/shared/ai_image_label).
  App.AiImageLabel = {
    markup: function(text, iconUrl) {
      return "<span class='ai-image-label' role='img' aria-label=\"" + text + "\">" +
        "<img class='ai-image-label--icon' src='" + iconUrl + "' alt='' aria-hidden='true'>" +
        "<span class='ai-image-label--text'>" + text + "</span>" +
        "</span>";
    }
  };
}).call(this);

// Minimal stand-in for App.ImageGallery in contexts where the legacy
// application.js bundle (which defines the real, GLightbox-based
// implementation) is not loaded — currently the /adm newsletter editor.
// Editor modules call App.ImageGallery.initialize() after DOM updates; a
// no-op is sufficient there because email content blocks don't use the
// lightbox. On legacy frontend pages application.js loads first, so the
// real implementation wins and this guard does nothing.
(function() {
  "use strict";

  window.App = window.App || {};

  if (!App.ImageGallery) {
    App.ImageGallery = {
      initialize() {}
    };
  }
}).call(this);

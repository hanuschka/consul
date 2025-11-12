(function() {
  "use strict";

  window.App.CustomFeatures = {
    aiEnabled: function() {
      return document.body.classList.contains('-ai-enabled');
    }
  };
})();

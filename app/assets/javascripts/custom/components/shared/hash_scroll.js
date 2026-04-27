(function() {
  "use strict";
  App.HashScroll = {
    TARGET_ID: "projekt-footer",
    TOP_OFFSET: 270,

    initialize() {
      if (window.location.hash !== "#" + this.TARGET_ID) return;

      window.addEventListener("load", this.scrollToTarget.bind(this));
    },

    scrollToTarget() {
      const targetElement = document.getElementById(this.TARGET_ID);

      if (!targetElement) return;

      window.scrollTo(0, targetElement.offsetTop - this.TOP_OFFSET);
    }
  };
}).call(this);

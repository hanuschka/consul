(function() {
  "use strict";

  App.HashScroll = {
    TARGET_ID: "projekt-footer",
    SETTLE_DELAY: 200,

    initialize() {
      if (window.location.hash !== "#" + this.TARGET_ID) return;

      this.target = document.getElementById(this.TARGET_ID);

      if (!this.target) return;

      this.pin();
      this.trackLayoutShifts();
      this.bindInterrupts();
    },

    pin() {
      this.target.scrollIntoView({ block: "start", inline: "nearest" });
    },

    trackLayoutShifts() {
      this.resizeObserver = new ResizeObserver(this.pin.bind(this));
      this.resizeObserver.observe(document.body);

      window.addEventListener("load", this.stopAfterSettle.bind(this));
    },

    stopAfterSettle() {
      window.setTimeout(this.stopTracking.bind(this), this.SETTLE_DELAY);
    },

    bindInterrupts() {
      const stop = this.stopTracking.bind(this);

      window.addEventListener("wheel", stop, { passive: true, once: true });
      window.addEventListener("touchmove", stop, { passive: true, once: true });
      window.addEventListener("keydown", stop, { once: true });
    },

    stopTracking() {
      this.resizeObserver.disconnect();
    }
  };
}).call(this);

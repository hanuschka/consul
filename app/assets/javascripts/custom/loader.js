(function() {
  "use strict";
  App.Loader = {
    initialized: false,
    initialize: function() {
      if (this.initialized) {
        return
      }
      window.addEventListener('message', this.handleGlobalMessage.bind(this));
      this.initialized = true;
      if (window.parent) { window.parent.postMessage(JSON.stringify({
        event_type: "initialized",
      }), '*'); }

    },

    handleGlobalMessage: function(event) {
      // console.log("handleGlobalMessage 1")
      if (event.data) {
        var data = {};
        console.log("window ivent", event, event.data)

        if (typeof event.data === "string") {
          data = JSON.parse(event.data);
        } else if (typeof event.data === "object"){
          data = event.data;
        }

        if (data.event_type === "load") {
          var s = document.createElement('script');

          s.src = data.src;
          s.type = 'text/javascript';
          document.body.appendChild(s);
        } else if (data.event_type === "load_st") {
          var l = document.createElement('link');

          l.href = data.src;
          l.rel = "stylesheet";
          document.head.appendChild(l);
        }
      }
    },
  };
}).call(this);

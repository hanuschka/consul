(function() {
  "use strict";
  App.Loader = {
    initialized: false,
    initialize: function() {
      if (this.initialized) return

      this.initialized = true;

      if (window.parent) {
        window.addEventListener('message', this.handleIframeGlobalEvents.bind(this));

        window.parent.postMessage(
          JSON.stringify({
            event_type: "consul_initialized",
          }),
          '*'
        );
      }
    },

    pageLoaded: function() {
      if (window.parent) {
        window.parent.postMessage(
          JSON.stringify({
            event_type: "consul_page_loaded",
          }),
          '*'
        );
      }
    },

    handleIframeGlobalEvents: function(event) {
      if (event.data) {
        var data = {};

        if (typeof event.data === "string") {
          data = JSON.parse(event.data);
        } else if (typeof event.data === "object"){
          data = event.data;
        }

        var params = data.params;

        if (data.event_type === "load_script") {
          var script = document.createElement('script');

          script.src = params.src;
          script.type = 'text/javascript';
          document.body.appendChild(script);
        } else if (data.event_type === "load_style") {
          var link = document.createElement('link');

          link.href = params.src;
          link.rel = "stylesheet";
          document.head.appendChild(link);
        }
      }
    },
  };
}).call(this);

(function() {
  "use strict";

  const POLL_INTERVAL_MS = 3000;
  const MAX_POLL_ATTEMPTS = 300;
  const MAX_POLL_FAILURES = 5;

  const MESSAGES = {
    timeout: "Zeitüberschreitung beim Generieren. Bitte versuchen Sie es erneut.",
    gone: "Die KI-Generierung ist fehlgeschlagen und wurde beendet.",
    unreachable: "Der Status der KI-Generierung ist nicht erreichbar.",
    failed: "Fehler beim Generieren des Inhaltsblocks."
  };

  App.Studio.ContentBlocks.AiGenerationPoller = {
    // handlers: onCompleted(response), onCancelled(), onError(message) and the
    // optional onProgress(stepLabel). Returns a handle whose stop() silences
    // every pending callback, so a caller that tears its dialog down cannot be
    // called back afterwards.
    start(statusUrl, handlers) {
      const poller = {
        active: true,
        stop() {
          this.active = false;
        }
      };

      let attempts = 0;
      let failures = 0;

      const abortWith = (message) => {
        poller.active = false;
        handlers.onError(message);
      };

      const scheduleNextPoll = () => setTimeout(tick, POLL_INTERVAL_MS);

      const handleResponse = (response) => {
        if (!poller.active) return

        failures = 0;

        if (handlers.onProgress && response.step_label) {
          handlers.onProgress(response.step_label);
        }

        if (response.status === "completed") {
          poller.active = false;
          handlers.onCompleted(response);
        } else if (response.status === "cancelled") {
          poller.active = false;
          handlers.onCancelled();
        } else if (response.status === "failed") {
          const message = response.error && response.error.message;
          abortWith(message || MESSAGES.failed);
        } else {
          scheduleNextPoll();
        }
      };

      // A 4xx means the generation record is gone or unreachable, so retrying
      // can only repeat it. Network blips and server errors get a bounded
      // number of retries rather than running out the whole attempt budget.
      const handleError = (xhr) => {
        if (!poller.active) return

        const status = xhr ? xhr.status : 0;

        if (status >= 400 && status < 500) {
          abortWith(MESSAGES.gone);
          return
        }

        failures++;

        if (failures >= MAX_POLL_FAILURES) {
          abortWith(MESSAGES.unreachable);
          return
        }

        scheduleNextPoll();
      };

      const tick = () => {
        if (!poller.active) return

        if (attempts >= MAX_POLL_ATTEMPTS) {
          abortWith(MESSAGES.timeout);
          return
        }

        attempts++;

        window.App.Ajax
          .request({
            url: statusUrl,
            method: "GET",
            dataType: "json"
          })
          .then(handleResponse)
          .catch(handleError);
      };

      tick();

      return poller;
    },

    // sendBeacon can only issue POST and carries no CSRF token, so it never
    // reached the DELETE-only cancel route. fetch with keepalive survives the
    // unload the same way while keeping one verb and one route.
    cancelOnUnload(cancelUrl) {
      const csrfMeta = document.querySelector('meta[name="csrf-token"]');

      fetch(cancelUrl, {
        method: "DELETE",
        keepalive: true,
        credentials: "same-origin",
        headers: {
          "X-CSRF-Token": csrfMeta ? csrfMeta.getAttribute("content") : "",
          "X-Requested-With": "XMLHttpRequest"
        }
      }).catch(() => {});
    }
  };
}).call(this);

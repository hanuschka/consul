(function() {
  "use strict";

  App.SimilarContributionsCheck = {
    initialize: function() {
      const section = this.getSection();

      if (!section) {
        return;
      }

      this.startedAt = Date.now();
      this.pollInterval = parseInt(section.dataset.pollInterval, 10);
      this.pollTimeout = parseInt(section.dataset.pollTimeout, 10);
      this.statusUrl = section.dataset.statusUrl;

      this.scheduleCheck();
    },

    getSection: function() {
      return document.querySelector(".js-similar-contributions-check");
    },

    scheduleCheck: function() {
      this.timer = window.setTimeout(() => this.check(), this.pollInterval);
    },

    // The citizen is blocked on this, so a stalled queue must not strand them:
    // once the ceiling is reached the contribution is published as if the check
    // had come back empty.
    check: function() {
      if (Date.now() - this.startedAt > this.pollTimeout) {
        this.publish();
        return;
      }

      App.Ajax
        .request({ url: this.statusUrl, method: "GET", dataType: "json" })
        .then((response) => this.handleStatus(response))
        .catch((request) => this.handleRequestError(request));
    },

    // A server that answered with an error is broken, not busy: retrying it for
    // the whole timeout window hides the fault and leaves the citizen waiting.
    // Only a request that never reached the server (status 0) is worth retrying.
    handleRequestError: function(request) {
      if (request && request.status > 0) {
        console.error("[SimilarContributionsCheck] status endpoint returned " + request.status);
        this.publish();
        return;
      }

      this.scheduleCheck();
    },

    handleStatus: function(response) {
      if (response.status === "failed") {
        this.publish();
        return;
      }

      if (response.status !== "completed") {
        this.scheduleCheck();
        return;
      }

      if (response.matches_count > 0) {
        this.showMatches(response.html);
      } else {
        this.publish();
      }
    },

    showMatches: function(html) {
      const section = this.getSection();

      section.querySelector(".js-similar-contributions-check-progress").innerHTML = "";
      section.querySelector(".js-similar-contributions-check-result").innerHTML = html;
    },

    publish: function() {
      const section = this.getSection();

      section.querySelector(".js-similar-contributions-check-publish").click();
    },

    teardown: function() {
      window.clearTimeout(this.timer);
    }
  };
}).call(this);

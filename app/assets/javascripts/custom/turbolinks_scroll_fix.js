(function() {
  "use strict";

  if ("scrollRestoration" in history) {
    history.scrollRestoration = "manual";
  }

  var isRestoreVisit = false;

  document.addEventListener("turbolinks:before-visit", function(event) {
    isRestoreVisit = event.data.action === "restore";
  });

  document.addEventListener("turbolinks:load", function() {
    if (!isRestoreVisit) {
      window.scrollTo(0, 0);
    }

    isRestoreVisit = false;
  });
}).call(this);

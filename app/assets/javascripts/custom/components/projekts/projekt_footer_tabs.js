(function() {
  "use strict";

  App.ProjektFooterTabs = {
    rootSelector: ".js-projekt-footer-tabs",

    initialize() {
      document.addEventListener("custom-tabs:change", this.handleChange.bind(this));
    },

    handleChange(event) {
      const root = event.target.closest(this.rootSelector);
      if (!root) return

      const section = event.detail.tab;
      const tab = root.querySelector('custom-tab[for="' + section + '"]');
      if (!tab) return

      const url = tab.dataset.url;
      if (!url) return

      this.updateUrl(section);
      this.showLoader();

      App.Ajax.request({ method: "GET", url: url, dataType: "script" });
    },

    updateUrl(section) {
      if (!history.pushState) return

      const url = new URL(window.location.href);

      if (section === "overview") {
        url.searchParams.delete("section");
      } else {
        url.searchParams.set("section", section);
      }

      history.pushState(null, "", url.toString());
    },

    showLoader() {
      $(".spinner-placeholder").addClass("show-loader");
    }
  };
}).call(this);

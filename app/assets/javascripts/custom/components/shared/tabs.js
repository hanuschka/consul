(function() {
  "use strict";

  // Universal tabs primitive. Markup contract:
  //   <ul class="shared-tabs js-tabs">
  //     <li class="shared-tabs--item is-active">
  //       <a class="shared-tabs--link js-tab" href="#panelId" aria-selected="true">…</a>
  //     </li>
  //   </ul>
  //   <div class="shared-tabs-panels">
  //     <div id="panelId" class="shared-tabs-panel is-active">…</div>
  //   </div>
  // Emits a bubbling "tabs:changed" event on the .js-tabs root after a switch.
  App.Tabs = {
    initialized: false,

    initialize() {
      if (this.initialized) return

      $(document).on("click", ".js-tabs .js-tab", this.handleTabClick.bind(this));

      this.initialized = true;
    },

    handleTabClick(e) {
      e.preventDefault();

      const clickedTabLink = e.currentTarget;
      const tabsRoot = clickedTabLink.closest(".js-tabs");

      tabsRoot.querySelectorAll(".js-tab").forEach((tabLink) => {
        const isClicked = tabLink === clickedTabLink;
        const panel = this.getPanelFor(tabLink);

        tabLink.closest("li").classList.toggle("is-active", isClicked);
        tabLink.setAttribute("aria-selected", String(isClicked));
        panel.classList.toggle("is-active", isClicked);
      });

      tabsRoot.dispatchEvent(new CustomEvent("tabs:changed", { bubbles: true }));
    },

    getPanelFor(tabLink) {
      return document.querySelector(tabLink.getAttribute("href"));
    }
  };
}).call(this);

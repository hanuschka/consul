(function() {
  "use strict";

  // <custom-tabs> is a light-DOM, framework-agnostic tab group. Because it is a
  // plain custom element it runs identically in the main app (Foundation /
  // Sprockets) and in /adm (esbuild / Stimulus) — the `elements` bundle is
  // loaded in both packs. It is composed of dedicated child elements:
  //
  //   <custom-tab for="X">        a clickable tab; its light-DOM children are
  //                               the label (icons, text, meta) and stay yours
  //   <custom-tab-panel for="X">  content shown while tab X is active; a panel
  //                               may list several tabs (for="X Y") to remain
  //                               visible under any of them (shared content)
  //
  // <custom-tabs> attributes (all optional):
  //   default   tab id active on first render (falls back to the tab marked
  //             [active], else the first tab)
  //   param     URL query-string key the active tab is synced into; on load a
  //             matching ?param=value overrides `default`
  //   all-tabbable  keep every tab a Tab key stop (tabindex=0) instead of the
  //             default roving-tabindex (only the active tab is a Tab stop,
  //             arrow keys move between the rest)
  //
  // It fires "custom-tabs:change" (bubbling) with detail { tab, previousTab }
  // on every activation, so consumers react to tab changes without the element
  // needing any domain knowledge of them.
  //
  // Styles live in app/assets/stylesheets/elements/custom_tabs.scss and are
  // pack-neutral (themeable via --custom-tabs-* custom properties).

  const TAB_TAG = "custom-tab";
  const PANEL_TAG = "custom-tab-panel";
  const CHANGE_EVENT = "custom-tabs:change";
  const NAV_KEYS = ["ArrowRight", "ArrowLeft", "Home", "End"];
  const ACTIVATE_KEYS = ["Enter", " "];

  let instanceCounter = 0;

  class CustomTabs extends HTMLElement {
    connectedCallback() {
      if (this.initialized) return

      if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", this.setup.bind(this), { once: true });
      } else {
        this.setup();
      }
    }

    setup() {
      if (this.initialized) return

      this.uid = instanceCounter++;
      this.param = this.getAttribute("param");
      this.wireAria();
      this.activeTab = this.initialTab();
      this.bindEvents();
      this.applyActiveTab();
      this.updateTabBarVisibility();
      this.observePreviewMode();

      this.initialized = true;
    }

    disconnectedCallback() {
      if (this.previewObserver) this.previewObserver.disconnect();
    }

    // A lone tab is pointless chrome: when only one tab is visible (the others
    // are absent or hidden, e.g. studio preview mode strips public-only tabs),
    // collapse the tablist so its single content panel shows straight away.
    updateTabBarVisibility() {
      const tabs = this.tabs();

      if (!tabs.length) return

      this.classList.remove("-single-tab");
      const visibleCount = tabs.filter((tab) => tab.getClientRects().length > 0).length;
      this.classList.toggle("-single-tab", visibleCount <= 1);
    }

    // Preview mode toggles a body class that hides js-studio-hide-on-preview
    // tabs via CSS, so the visible-tab count changes without any DOM mutation
    // inside this element — recompute only when that state actually flips.
    observePreviewMode() {
      this.previewActive = document.body.classList.contains("-preview-mode");
      this.previewObserver = new MutationObserver(this.handleBodyMutation.bind(this));
      this.previewObserver.observe(document.body, { attributes: true, attributeFilter: ["class"] });
    }

    handleBodyMutation() {
      const previewActive = document.body.classList.contains("-preview-mode");

      if (previewActive === this.previewActive) return

      this.previewActive = previewActive;
      this.updateTabBarVisibility();
    }

    bindEvents() {
      this.addEventListener("click", this.handleClick.bind(this));
      this.addEventListener("keydown", this.handleKeydown.bind(this));
    }

    tabs() {
      return Array.from(this.querySelectorAll(TAB_TAG));
    }

    panels() {
      return Array.from(this.querySelectorAll(PANEL_TAG));
    }

    tabId(tab) {
      return tab.getAttribute("for");
    }

    // role=tablist belongs on the element wrapping the tabs, and each tab/panel
    // pair is linked via generated ids so screen readers announce the relation.
    wireAria() {
      const tabs = this.tabs();

      if (!tabs.length) return

      const list = tabs[0].parentElement;
      list.setAttribute("role", "tablist");
      list.setAttribute("aria-orientation", "horizontal");

      tabs.forEach((tab, index) => {
        const key = this.tabId(tab);

        if (!tab.id) tab.id = `custom-tab-${this.uid}-${index}`;

        const panelIds = this.panelsFor(key).map((panel) => this.ensurePanelId(panel));

        if (panelIds.length) tab.setAttribute("aria-controls", panelIds.join(" "));
        this.labelPanels(key, tab.id);
      });
    }

    panelsFor(key) {
      return this.panels().filter((panel) => this.panelOwners(panel).includes(key));
    }

    labelPanels(key, tabDomId) {
      this.panelsFor(key).forEach((panel) => {
        if (!panel.hasAttribute("aria-labelledby")) panel.setAttribute("aria-labelledby", tabDomId);
      });
    }

    ensurePanelId(panel) {
      if (!panel.id) panel.id = `custom-tab-panel-${this.uid}-${this.panels().indexOf(panel)}`;

      return panel.id;
    }

    panelOwners(panel) {
      return (panel.getAttribute("for") || "").split(/\s+/).filter(Boolean);
    }

    initialTab() {
      const tabs = this.tabs();

      if (!tabs.length) return null

      const fromUrl = this.tabFromUrl();
      if (fromUrl && tabs.some((tab) => this.tabId(tab) === fromUrl)) return fromUrl

      const preset = this.getAttribute("default");
      if (preset && tabs.some((tab) => this.tabId(tab) === preset)) return preset

      const active = tabs.find((tab) => tab.hasAttribute("active"));
      if (active) return this.tabId(active)

      return this.tabId(tabs[0]);
    }

    tabFromUrl() {
      if (!this.param) return null

      return new URLSearchParams(window.location.search).get(this.param);
    }

    handleClick(event) {
      const tab = event.target.closest(TAB_TAG);

      if (!tab || !this.contains(tab)) return

      this.activate(this.tabId(tab));
    }

    handleKeydown(event) {
      const tab = event.target.closest(TAB_TAG);

      if (!tab || !this.contains(tab)) return

      if (ACTIVATE_KEYS.includes(event.key)) {
        event.preventDefault();
        this.activate(this.tabId(tab));

        return
      }

      if (!NAV_KEYS.includes(event.key)) return

      event.preventDefault();
      this.moveFocus(tab, event.key);
    }

    moveFocus(currentTab, key) {
      const tabs = this.tabs();
      const index = tabs.indexOf(currentTab);
      let nextIndex = index;

      if (key === "ArrowRight") nextIndex = (index + 1) % tabs.length;
      if (key === "ArrowLeft") nextIndex = (index - 1 + tabs.length) % tabs.length;
      if (key === "Home") nextIndex = 0;
      if (key === "End") nextIndex = tabs.length - 1;

      const nextTab = tabs[nextIndex];
      nextTab.focus();
      this.activate(this.tabId(nextTab));
    }

    activate(tab) {
      if (!tab || tab === this.activeTab) return

      const previousTab = this.activeTab;
      this.activeTab = tab;
      this.applyActiveTab();
      this.syncUrl();
      this.emitChange(previousTab);
    }

    applyActiveTab() {
      const allTabbable = this.hasAttribute("all-tabbable");

      this.tabs().forEach((tab) => {
        const active = this.tabId(tab) === this.activeTab;

        tab.classList.toggle("-active", active);
        tab.setAttribute("aria-selected", active ? "true" : "false");
        tab.setAttribute("tabindex", active || allTabbable ? "0" : "-1");
      });

      this.panels().forEach((panel) => {
        panel.hidden = !this.panelOwners(panel).includes(this.activeTab);
      });
    }

    syncUrl() {
      if (!this.param) return

      const url = new URL(window.location.href);
      const isDefault = this.activeTab === this.getAttribute("default");

      if (isDefault) {
        url.searchParams.delete(this.param);
      } else {
        url.searchParams.set(this.param, this.activeTab);
      }

      window.history.replaceState(window.history.state, "", url);
    }

    emitChange(previousTab) {
      this.dispatchEvent(new CustomEvent(CHANGE_EVENT, {
        bubbles: true,
        detail: { tab: this.activeTab, previousTab: previousTab }
      }));
    }
  }

  class CustomTab extends HTMLElement {
    connectedCallback() {
      this.setAttribute("role", "tab");

      if (!this.hasAttribute("tabindex")) this.setAttribute("tabindex", "-1");
    }
  }

  class CustomTabPanel extends HTMLElement {
    connectedCallback() {
      this.setAttribute("role", "tabpanel");
    }
  }

  customElements.define("custom-tabs", CustomTabs);
  customElements.define(TAB_TAG, CustomTab);
  customElements.define(PANEL_TAG, CustomTabPanel);
}).call(this);

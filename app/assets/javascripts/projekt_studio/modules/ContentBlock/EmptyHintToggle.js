// Toggles the `is-content-empty` marker class on sidebar cards (or any
// container) marked with `.js-toggle-empty-hint-on-content`, based on the
// emptiness of the editable content block inside.
//
// The server-side ERB sets the initial class via `content_block_body_blank?`.
// This module keeps the class in sync after inline edits, where
// `App.ContentBlockEditor.Crud.updateContentBlock` mutates the DOM directly
// (`contentBlock.innerHTML = ...`) without a page reload.
//
// We use a MutationObserver per container so that any mutation inside — text
// edits, full innerHTML replacement after save (Crud.syncDomFromServer), or
// rewrap by `App.Studio.SiteContentBlockEditor.wrapContentBlocks` — re-runs
// the emptiness check. The check delegates to
// `App.ContentBlockEditor.Crud.isContentEmpty(html)` so the JS state stays
// consistent with the Ruby `content_block_body_blank?` rule (strip <br>, <p>,
// <div>, <span>, whitespace, then check for any remaining characters).
App.ContentBlockEditor.EmptyHintToggle = {
  markerClass: "is-content-empty",
  containerSelector: ".js-toggle-empty-hint-on-content",
  observers: new WeakMap(),

  initialize() {
    this.refreshAll();

    // Re-scan on Turbolinks navigation (handled in main.js via reinitializeUI,
    // but we also re-scan when ProjektStudio re-runs init in this session).
  },

  refreshAll() {
    const containers = document.querySelectorAll(this.containerSelector);

    containers.forEach((container) => {
      this.attach(container);
      this.evaluate(container);
    });
  },

  attach(container) {
    if (this.observers.has(container)) return;

    const observer = new MutationObserver(() => {
      // Debounce via microtask: many mutations from a single innerHTML
      // assignment would otherwise trigger N evaluations.
      if (container.__emptyHintScheduled) return;
      container.__emptyHintScheduled = true;

      Promise.resolve().then(() => {
        container.__emptyHintScheduled = false;
        this.evaluate(container);
      });
    });

    observer.observe(container, {
      childList: true,
      subtree: true,
      characterData: true
    });

    this.observers.set(container, observer);
  },

  evaluate(container) {
    const body = this.findBody(container);

    // No editable body present: treat as empty so the hint stays visible.
    const isEmpty = !body || this.isBodyEmpty(body);

    container.classList.toggle(this.markerClass, isEmpty);
  },

  // Locate the actual content body inside the container. Prefer the
  // `.custom-content-block-body` element when present; fall back to the
  // `.js-content-block` wrapper that ProjektStudio places around the
  // editable content (after save the inner `.custom-content-block-body` may
  // be replaced by raw body HTML).
  findBody(container) {
    return (
      container.querySelector(".custom-content-block-body") ||
      container.querySelector(".js-content-block")
    );
  },

  isBodyEmpty(body) {
    const crud = App.ContentBlockEditor.Crud;

    if (crud && typeof crud.isContentEmpty === "function") {
      return crud.isContentEmpty(body.innerHTML);
    }

    // Fallback — mirrors Crud.isContentEmpty.
    const stripped = body.innerHTML
      .replace(/<br\s*\/?>/gi, "")
      .replace(/<\/?(p|div|span)(\s[^>]*)?>/gi, "")
      .replace(/[\s ]/g, "");

    return stripped.length === 0;
  }
};

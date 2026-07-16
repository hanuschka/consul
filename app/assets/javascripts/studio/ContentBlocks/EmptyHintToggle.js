// Toggles the `is-content-empty` marker class on sidebar cards (or any
// container) marked with `.js-toggle-empty-hint-on-content`, based on the
// emptiness of the editable content block inside.
//
// The server-side ERB sets the initial class via `content_block_body_blank?`.
// This module keeps the class in sync after inline edits, where
// `App.Studio.ContentBlocks.Crud.updateContentBlock` mutates the DOM directly
// (`contentBlock.innerHTML = ...`) without a page reload.
//
// We use a MutationObserver per container so that any mutation inside — full
// innerHTML replacement after save (Crud.syncDomFromServer), content restore on
// cancel, or rewrap by `App.Studio.SiteContentBlockEditor.wrapContentBlocks` —
// re-runs the emptiness check. The check delegates to
// `App.Studio.ContentBlocks.Crud.isContentEmpty(html)` so the JS state stays
// consistent with the Ruby `content_block_body_blank?` rule (strip <br>, <p>,
// <div>, <span>, whitespace, then check for any remaining characters).
//
// The marker is NOT re-evaluated while the block is being edited: keystrokes in
// the contentEditable body would otherwise flip the hint on/off mid-typing.
// `evaluate` runs on a microtask (see `attach`), i.e. after the current
// synchronous handler finishes — so on save/cancel, which clear the wrapper's
// edit-mode state within that same handler (whether before or after they mutate
// the body), the check sees edit mode already off and settles the marker then.
App.Studio.ContentBlocks.EmptyHintToggle = {
  markerClass: "is-content-empty",
  containerSelector: ".js-toggle-empty-hint-on-content",
  observers: new WeakMap(),

  initialize() {
    this.refreshAll();

    // Re-scan on Turbolinks navigation (handled in main.js via reinitializeUI,
    // but we also re-scan when App.Studio.Projekt re-runs init in this session).
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
    if (this.isEditing(container)) return

    const body = this.findBody(container);

    // No editable body present: treat as empty so the hint stays visible.
    const isEmpty = !body || this.isBodyEmpty(body);

    container.classList.toggle(this.markerClass, isEmpty);

    if (isEmpty) {
      this.reserveHintHeight(container);
    }
  },

  // True while any edit mode (simple/ai/code/html) is active on the wrapped
  // content block, so typing doesn't toggle the marker. The container is either
  // the wrapper itself (projekt-page block) or an ancestor of it (site block /
  // sidebar card).
  isEditing(container) {
    const wrapper = container.classList.contains("custom-content-block-wrapper")
      ? container
      : container.querySelector(".custom-content-block-wrapper");

    if (!wrapper) return false

    return wrapper.classList.contains("-in-edit-mode") || !!wrapper.dataset.editMode;
  },

  // Stash the visible hint's height as --empty-hint-height so the CSS can give
  // the editable body that same min-height in edit mode (when the hint is
  // hidden). Only update while the hint is actually visible (offsetHeight > 0);
  // once edit mode hides it the last good value is kept, avoiding a clobber.
  reserveHintHeight(container) {
    const hint = container.querySelector(".js-content-block-empty-hint");

    if (!hint) return
    if (hint.offsetHeight === 0) return

    container.style.setProperty("--empty-hint-height", `${hint.offsetHeight}px`);
  },

  // Locate the actual content body inside the container. Prefer the
  // `.custom-content-block-body` element when present; fall back to the
  // `.js-content-block` wrapper that App.Studio.Projekt places around the
  // editable content (after save the inner `.custom-content-block-body` may
  // be replaced by raw body HTML).
  findBody(container) {
    return (
      container.querySelector(".custom-content-block-body") ||
      container.querySelector(".js-content-block")
    );
  },

  isBodyEmpty(body) {
    const crud = App.Studio.ContentBlocks.Crud;

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

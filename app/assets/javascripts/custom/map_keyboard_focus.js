(function() {
  "use strict";

  const FOCUSABLE_SELECTOR =
    'a[href], button, input, select, textarea, [tabindex], area, iframe, [contenteditable]';

  App.MapKeyboardFocus = {
    neutralize(container) {
      if (!container) return;

      this.removeFromTabOrder(container);
      this.observe(container);
    },

    removeFromTabOrder(container) {
      if (container.getAttribute("tabindex") !== "-1") {
        container.setAttribute("tabindex", "-1");
      }

      container.querySelectorAll(FOCUSABLE_SELECTOR).forEach((element) => {
        if (element.getAttribute("tabindex") !== "-1") {
          element.setAttribute("tabindex", "-1");
        }
      });
    },

    observe(container) {
      if (container.dataset.keyboardFocusObserved) return;

      container.dataset.keyboardFocusObserved = "true";

      let scheduled = false;
      const observer = new MutationObserver(() => {
        if (scheduled) return;

        scheduled = true;
        setTimeout(() => {
          scheduled = false;
          this.removeFromTabOrder(container);
        }, 100);
      });

      observer.observe(container, { childList: true, subtree: true });
    }
  };
}).call(this);

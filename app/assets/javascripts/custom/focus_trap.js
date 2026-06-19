(function() {
  "use strict";

  App.FocusTrap = {
    DISABLED: true,

    FOCUSABLE_SELECTORS: [
      'a[href]:not([disabled])',
      'button:not([disabled])',
      'input:not([disabled]):not([type="hidden"])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      'iframe',
      'audio[controls]',
      'video[controls]',
      '[contenteditable]:not([contenteditable="false"])',
      '[tabindex]:not([tabindex="-1"]):not([disabled])'
    ].join(', '),

    inertStack: [],

    bound: false,
    observer: null,
    pruneScheduled: false,

    initialize: function() {
      if (this.bound) return;

      this.bound = true;

      var prune = this.pruneStaleTraps.bind(this);

      document.addEventListener("focusin", prune, true);
      document.addEventListener("keydown", prune, true);
      document.addEventListener("click", prune, true);
    },

    startWatching: function() {
      if (this.observer) return;

      this.observer = new MutationObserver(this.schedulePrune.bind(this));
      this.observer.observe(document.body, {
        childList: true,
        subtree: true,
        attributes: true,
        attributeFilter: ["style", "class", "hidden", "open"]
      });
    },

    stopWatching: function() {
      if (!this.observer) return;

      this.observer.disconnect();
      this.observer = null;
    },

    schedulePrune: function() {
      if (this.pruneScheduled) return;

      this.pruneScheduled = true;

      window.requestAnimationFrame(function() {
        App.FocusTrap.pruneScheduled = false;
        App.FocusTrap.pruneStaleTraps();
      });
    },

    pruneStaleTraps: function() {
      while (this.inertStack.length > 0 && this.isTopTrapStale()) {
        this.removeBackgroundInert();
      }
    },

    isTopTrapStale: function() {
      var entry = this.inertStack[this.inertStack.length - 1];

      if (!entry || !entry.owner) return true;

      return !this.isVisible(entry.owner);
    },

    isVisible: function(el) {
      return !!el && el.isConnected && el.getClientRects().length > 0;
    },

    getFocusableElements: function(container) {
      if (!container) return [];

      var all = container.querySelectorAll(this.FOCUSABLE_SELECTORS);

      return Array.from(all).filter(function(el) {
        if (el.closest('[inert]')) return false;
        if (el.offsetParent === null && window.getComputedStyle(el).position !== 'fixed') return false;
        if (el.offsetWidth === 0 && el.offsetHeight === 0) return false;

        var style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') return false;

        return true;
      });
    },

    handleTabKey: function(event, container, extraFocusableElements) {
      if (this.DISABLED) return;

      var focusable = this.getFocusableElements(container);

      if (extraFocusableElements) {
        extraFocusableElements.forEach(function(el) {
          if (el && focusable.indexOf(el) === -1) {
            focusable.unshift(el);
          }
        });
      }

      if (focusable.length === 0) return;

      var first = focusable[0];
      var last = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    },

    setBackgroundInert: function(excludeElements, ownerElement) {
      if (this.DISABLED) return;

      var exclude = (excludeElements || []).filter(Boolean);
      var owner = ownerElement || exclude[0] || null;

      this.inertStack.push({ exclude: exclude, owner: owner });
      this.applyInert(exclude);
      this.startWatching();
    },

    removeBackgroundInert: function() {
      if (this.inertStack.length === 0) {
        this.clearInert();
        this.stopWatching();
        return;
      }

      this.inertStack.pop();
      this.clearInert();

      var previous = this.inertStack[this.inertStack.length - 1];

      if (previous) {
        this.applyInert(previous.exclude);
      } else {
        this.stopWatching();
      }
    },

    resetInert: function() {
      this.inertStack = [];
      this.clearInert();
      this.stopWatching();
    },

    applyInert: function(excludeElements) {
      var bodyChildren = document.body.children;

      for (var i = 0; i < bodyChildren.length; i++) {
        var child = bodyChildren[i];
        if (child.nodeType !== 1) continue;
        if (child.tagName === 'SCRIPT' || child.tagName === 'STYLE' || child.tagName === 'LINK') continue;

        var shouldExclude = false;

        for (var j = 0; j < excludeElements.length; j++) {
          if (child === excludeElements[j] || child.contains(excludeElements[j])) {
            shouldExclude = true;
            break;
          }
        }

        if (shouldExclude) {
          if (child.hasAttribute('data-focus-trap-inert')) {
            child.removeAttribute('inert');
            child.removeAttribute('data-focus-trap-inert');
          }
        } else {
          child.setAttribute('inert', '');
          child.setAttribute('data-focus-trap-inert', '');
        }
      }
    },

    clearInert: function() {
      var inertElements = document.querySelectorAll('[data-focus-trap-inert]');

      for (var i = 0; i < inertElements.length; i++) {
        inertElements[i].removeAttribute('inert');
        inertElements[i].removeAttribute('data-focus-trap-inert');
      }
    }
  };
}).call(this);

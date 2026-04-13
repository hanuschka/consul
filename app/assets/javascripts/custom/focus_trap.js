(function() {
  "use strict";

  App.FocusTrap = {
    FOCUSABLE_SELECTORS: [
      'a[href]:not([disabled])',
      'button:not([disabled])',
      'input:not([disabled])',
      'select:not([disabled])',
      'textarea:not([disabled])',
      '[tabindex]:not([tabindex="-1"]):not([disabled])'
    ].join(', '),

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

    setBackgroundInert: function(excludeElements) {
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

        if (!shouldExclude) {
          child.setAttribute('inert', '');
          child.setAttribute('data-focus-trap-inert', '');
        }
      }
    },

    removeBackgroundInert: function() {
      var inertElements = document.querySelectorAll('[data-focus-trap-inert]');

      for (var i = 0; i < inertElements.length; i++) {
        inertElements[i].removeAttribute('inert');
        inertElements[i].removeAttribute('data-focus-trap-inert');
      }
    }
  };
}).call(this);

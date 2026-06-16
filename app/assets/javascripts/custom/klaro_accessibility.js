(function() {
  "use strict";

  App.KlaroAccessibility = {
    isModalActive: false,
    klaroElement: null,
    observer: null,

    initialize: function() {
      this.klaroElement = document.getElementById('klaro');

      if (this.klaroElement) {
        this.startObserving();
      } else {
        this.waitForKlaro();
      }
    },

    waitForKlaro: function() {
      var bodyObserver = new MutationObserver(() => {
        this.klaroElement = document.getElementById('klaro');

        if (this.klaroElement) {
          bodyObserver.disconnect();
          this.startObserving();
        }
      });

      bodyObserver.observe(document.body, { childList: true });
    },

    startObserving: function() {
      this.observer = new MutationObserver(() => {
        this.checkModalState();
      });

      this.observer.observe(this.klaroElement, { childList: true, subtree: true });
      this.checkModalState();
      this.bindKeyHandler();
    },

    getModalContainer: function() {
      if (!this.klaroElement) return null;

      var candidates = this.klaroElement.querySelectorAll('.cookie-modal, .cookie-modal-notice');

      for (var i = 0; i < candidates.length; i++) {
        if (candidates[i].offsetParent !== null) return candidates[i];
      }

      return null;
    },

    checkModalState: function() {
      var modal = this.getModalContainer();
      var isVisible = modal && modal.offsetParent !== null;

      if (isVisible && !this.isModalActive) {
        this.activateTrap(modal);
      } else if (!isVisible && this.isModalActive) {
        this.deactivateTrap();
      }
    },

    activateTrap: function(modal) {
      this.isModalActive = true;

      var dialogEl = modal.querySelector('.cm-modal') || modal;
      dialogEl.setAttribute('role', 'dialog');
      dialogEl.setAttribute('aria-modal', 'true');

      App.FocusTrap.setBackgroundInert([this.klaroElement]);

      setTimeout(() => {
        var focusable = App.FocusTrap.getFocusableElements(modal);

        if (focusable.length > 0) {
          focusable[0].focus();
        }
      }, 50);
    },

    deactivateTrap: function() {
      this.isModalActive = false;
      App.FocusTrap.removeBackgroundInert();
    },

    bindKeyHandler: function() {
      document.addEventListener('keydown', (event) => {
        if (!this.isModalActive) return;
        if (event.key !== 'Tab' && event.which !== 9) return;

        var modal = this.getModalContainer();
        if (!modal) return;

        App.FocusTrap.handleTabKey(event, modal);
      });
    }
  };
}).call(this);

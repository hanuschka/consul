(function() {
  "use strict";
  App.ResponsiveMenu = {

    toggleMenu: function($arrow) {
      console.log($arrow.prop('tagName') + '.' + $arrow.prop('className'))
      var $navElement = $arrow.closest('li.nav-element')
      var $navElementValue = ( $navElement.attr('aria-expanded') == 'true' )
      $navElement.attr('aria-expanded', !$navElementValue )
    },

    isMobileMenuOpen: function() {
      return $('#responsive-menu').is(':visible');
    },

    closeMobileMenu: function() {
      $('#responsive-menu').hide();
      $('.js-toggle-mobile-menu').attr('aria-expanded', 'false');
      $('.js-toggle-mobile-menu').focus();
    },

    getFocusableElements: function() {
      var menu = document.getElementById('responsive-menu');
      if (!menu) return [];

      var focusableSelectors = [
        'a[href]:not([disabled])',
        'button:not([disabled])',
        'input:not([disabled])',
        'select:not([disabled])',
        'textarea:not([disabled])',
        '[tabindex]:not([tabindex="-1"]):not([disabled])'
      ].join(', ');

      var allFocusable = menu.querySelectorAll(focusableSelectors);

      return Array.from(allFocusable).filter(function(el) {
        if (el.offsetParent === null) return false;
        if (el.offsetWidth === 0 && el.offsetHeight === 0) return false;

        var style = window.getComputedStyle(el);
        if (style.display === 'none' || style.visibility === 'hidden') return false;

        var parent = el.parentElement;
        while (parent && parent !== menu) {
          var parentStyle = window.getComputedStyle(parent);
          if (parentStyle.display === 'none' || parentStyle.visibility === 'hidden') {
            return false;
          }
          parent = parent.parentElement;
        }

        return true;
      });
    },

    handleTabKey: function(event) {
      if (!App.ResponsiveMenu.isMobileMenuOpen()) return;

      var focusable = App.ResponsiveMenu.getFocusableElements();
      if (focusable.length === 0) return;

      var firstFocusable = focusable[0];
      var lastFocusable = focusable[focusable.length - 1];

      if (event.shiftKey && document.activeElement === firstFocusable) {
        event.preventDefault();
        lastFocusable.focus();
      } else if (!event.shiftKey && document.activeElement === lastFocusable) {
        event.preventDefault();
        firstFocusable.focus();
      }
    },

    trapFocus: function(event) {
      if (!App.ResponsiveMenu.isMobileMenuOpen()) return;

      var menu = document.getElementById('responsive-menu');
      if (!menu) return;

      if (!menu.contains(document.activeElement) && !document.querySelector('.js-toggle-mobile-menu').contains(document.activeElement)) {
        var focusable = App.ResponsiveMenu.getFocusableElements();
        if (focusable.length > 0) {
          focusable[0].focus();
        }
      }
    },

    initialize: function() {

      $("body").on("click", ".js-toggle-mobile-flyout-item", function() {
        App.ResponsiveMenu.toggleMenu($(this))
      });

      $("body").on("keyup", ".js-toggle-mobile-flyout-item", function() {
        var $menuOpen = $(this).closest('.nav-element').attr('aria-expanded') == 'true'
        if ( ( event.which == 40 && !$menuOpen ) || // down arrow
             ( event.which == 38 && $menuOpen )  ) { // up arrow
          App.ResponsiveMenu.toggleMenu($(this))
        }

      });

      $("body").on("keyup", ".js-toggle-mobile-menu", function() {
        if ( event.which == 32 || event.which == 13 ) {
          event.preventDefault();
          $('#responsive-menu').toggle();
          var menuVisible = $('#responsive-menu').is(':visible');
          $(this).attr('aria-expanded', menuVisible);
        }
      });

      $(document).on("keydown", function(event) {
        if (event.which === 27 && App.ResponsiveMenu.isMobileMenuOpen()) {
          event.preventDefault();
          App.ResponsiveMenu.closeMobileMenu();
        }

        if (event.which === 9 && App.ResponsiveMenu.isMobileMenuOpen()) {
          App.ResponsiveMenu.handleTabKey(event);
        }
      });

      $(document).on("focusin", function() {
        App.ResponsiveMenu.trapFocus();
      });

    }
  };
}).call(this);

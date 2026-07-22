(function() {
  "use strict";

  var recentTouch = false;

  App.ResponsiveMenu = {

    toggleMenu: function($arrow) {
      var $navElement = $arrow.closest('li.nav-element');
      var wasOpen = ( $navElement.attr('aria-expanded') == 'true' );
      $navElement.attr('aria-expanded', !wasOpen);
      $arrow.attr('aria-expanded', !wasOpen);
    },

    isMobileMenuOpen: function() {
      return $('#responsive-menu').is(':visible');
    },

    closeMobileMenu: function() {
      $('#responsive-menu').hide();
      $('.js-toggle-mobile-menu').attr('aria-expanded', 'false');
      this.updateBackgroundInert(false);
      $('.js-toggle-mobile-menu').focus();
    },

    updateBackgroundInert: function(menuVisible) {
      if (menuVisible) {
        var header = document.querySelector('header');
        var menuWrapper = document.querySelector('.header--responsive-menu-wrapper');
        var excludeElements = [];

        if (header) excludeElements.push(header);
        if (menuWrapper) excludeElements.push(menuWrapper);

        App.FocusTrap.setBackgroundInert(excludeElements, document.getElementById('responsive-menu'));
      } else {
        App.FocusTrap.removeBackgroundInert();
      }
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

    getToggleButton: function() {
      return document.querySelector('.js-toggle-mobile-menu');
    },

    handleToggleKey: function(event) {
      if (event.which !== 13 && event.which !== 32) return;

      event.preventDefault();
      $(this).find('[data-toggle]').trigger('click');
    },

    handleTabKey: function(event) {
      if (!App.ResponsiveMenu.isMobileMenuOpen()) return;

      var focusable = App.ResponsiveMenu.getFocusableElements();
      if (focusable.length === 0) return;

      var toggleButton = App.ResponsiveMenu.getToggleButton();
      var firstFocusable = focusable[0];
      var lastFocusable = focusable[focusable.length - 1];

      if (document.activeElement === toggleButton) {
        event.preventDefault();
        if (event.shiftKey) {
          lastFocusable.focus();
        } else {
          firstFocusable.focus();
        }
      } else if (event.shiftKey && document.activeElement === firstFocusable) {
        event.preventDefault();
        toggleButton.focus();
      } else if (!event.shiftKey && document.activeElement === lastFocusable) {
        event.preventDefault();
        toggleButton.focus();
      }
    },

    trapFocus: function() {
      if (!App.ResponsiveMenu.isMobileMenuOpen()) return;

      var menu = document.getElementById('responsive-menu');
      if (!menu) return;

      var toggleButton = App.ResponsiveMenu.getToggleButton();
      var isInMenu = menu.contains(document.activeElement);
      var isOnToggle = toggleButton && toggleButton.contains(document.activeElement);

      if (!isInMenu && !isOnToggle) {
        var focusable = App.ResponsiveMenu.getFocusableElements();
        if (focusable.length > 0) {
          focusable[0].focus();
        }
      }
    },

    initPriorityPlus: function() {
      var $navbar = $('[data-navbar]').not('#responsive-menu [data-navbar]').first();
      if (!$navbar.length) return;

      this.removeExistingMoreItem($navbar);

      var moreLabel = $navbar.attr('data-navbar-more-label') || 'More';
      var moreSubmenuId = 'navbar-submenu-more';
      var $moreItem = $(
        '<li class="nav-element top-level-item navbar-more-item" aria-expanded="false">' +
          '<a href="#">' + moreLabel + '</a>' +
          '<button type="button" class="nav-toggle-arrow" aria-expanded="false" aria-haspopup="true"' +
            ' aria-controls="' + moreSubmenuId + '" aria-label="' + moreLabel + '"' +
            ' data-navbar-toggle><span aria-hidden="true">&#9660;</span></button>' +
          '<ul id="' + moreSubmenuId + '" class="nav-flyout-block"></ul>' +
        '</li>'
      );
      var $moreFlyout = $moreItem.children('ul.nav-flyout-block');
      var $allItems = $navbar.children('li.nav-element.top-level-item');

      // Insert "More" at the end, hidden initially
      $navbar.append($moreItem);
      $moreItem.hide();

      function redistribute() {
        // Return all overflow items back to the navbar
        $moreFlyout.children('li').each(function() {
          $(this).removeClass('flyout-item').addClass('top-level-item');
          $moreItem.before(this);
        });
        $moreItem.hide();

        // Check if anything wraps without "More"
        var $items = $navbar.children('li.nav-element.top-level-item').not($moreItem);
        if (!$items.length) return;

        var firstTop = Math.round($items.first()[0].getBoundingClientRect().top);
        var needsMore = false;
        $items.each(function() {
          if (Math.round(this.getBoundingClientRect().top) > firstTop) {
            needsMore = true;
            return false;
          }
        });

        if (!needsMore) return; // everything fits

        // Show "More" and move items from the end until everything fits on one row
        $moreItem.show();

        while (true) {
          var $remaining = $navbar.children('li.nav-element.top-level-item').not($moreItem);
          if (!$remaining.length) break;

          var rowTop = Math.round($remaining.first()[0].getBoundingClientRect().top);
          var moreTop = Math.round($moreItem[0].getBoundingClientRect().top);
          if (moreTop <= rowTop) break;

          var $last = $remaining.last();
          $last.removeClass('top-level-item').addClass('flyout-item');
          $moreFlyout.prepend($last);
        }
      }

      redistribute();

      App.ResponsiveMenu.latestRedistribute = redistribute;
      App.ResponsiveMenu.bindResizeOnce();
      App.ResponsiveMenu.bindLateLayoutShiftsOnce();
      App.ResponsiveMenu.observeNavbarWidth($navbar[0]);
    },

    removeExistingMoreItem: function($navbar) {
      var $existingMore = $navbar.children('li.navbar-more-item');
      if (!$existingMore.length) return;

      $existingMore.children('ul').children('li').each(function() {
        $(this).removeClass('flyout-item').addClass('top-level-item');
        $existingMore.before(this);
      });

      $existingMore.remove();
    },

    scheduleRedistribute: function() {
      clearTimeout(this.redistributeTimer);
      this.redistributeTimer = setTimeout(function() {
        if (App.ResponsiveMenu.latestRedistribute) {
          App.ResponsiveMenu.latestRedistribute();
        }
      }, 100);
    },

    bindResizeOnce: function() {
      if (this.resizeBound) return;

      this.resizeBound = true;

      $(window).on('resize', function() {
        App.ResponsiveMenu.scheduleRedistribute();
      });
    },

    bindLateLayoutShiftsOnce: function() {
      if (this.lateLayoutShiftsBound) return;

      this.lateLayoutShiftsBound = true;

      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(function() {
          App.ResponsiveMenu.scheduleRedistribute();
        });
      }

      $(window).on('load', function() {
        App.ResponsiveMenu.scheduleRedistribute();
      });
    },

    observeNavbarWidth: function(navbar) {
      if (typeof ResizeObserver === 'undefined') return;

      if (this.navbarWidthObserver) {
        this.navbarWidthObserver.disconnect();
      }

      var observedElement = navbar;
      while (observedElement && window.getComputedStyle(observedElement).display === 'contents') {
        observedElement = observedElement.parentElement;
      }

      if (!observedElement) return;

      var lastWidth = Math.round(observedElement.getBoundingClientRect().width);
      this.navbarWidthObserver = new ResizeObserver(function(entries) {
        var newWidth = Math.round(entries[0].contentRect.width);

        if (newWidth === lastWidth) return;

        lastWidth = newWidth;
        App.ResponsiveMenu.scheduleRedistribute();
      });

      this.navbarWidthObserver.observe(observedElement);
    },

    initialize: function() {
      this.bindBodyEvents();
      this.bindGlobalEvents();
      this.initPriorityPlus();
    },

    destroy: function() {
      var $navbar = $('[data-navbar]').not('#responsive-menu [data-navbar]').first();

      if ($navbar.length) {
        this.removeExistingMoreItem($navbar);
      }

      if (this.navbarWidthObserver) {
        this.navbarWidthObserver.disconnect();
        this.navbarWidthObserver = null;
      }

      this.latestRedistribute = null;
    },

    bindBodyEvents: function() {
      $("body").on("click", ".js-toggle-mobile-flyout-item, [data-navbar-toggle]", function(event) {
        event.preventDefault();
        event.stopPropagation();
        App.ResponsiveMenu.toggleMenu($(this))
      });

      $("body").on("keyup", ".js-toggle-mobile-flyout-item, [data-navbar-toggle]", function(event) {
        var $menuOpen = $(this).closest('.nav-element').attr('aria-expanded') == 'true'
        if ( ( event.which == 40 && !$menuOpen ) || // down arrow
             ( event.which == 38 && $menuOpen )  ) { // up arrow
          App.ResponsiveMenu.toggleMenu($(this))
        }

      });

      $("body").on("keydown", ".js-toggle-mobile-menu", App.ResponsiveMenu.handleToggleKey);

      $("body").on("click", ".js-toggle-mobile-menu", function() {
        var $button = $(this);
        setTimeout(function() {
          var menuVisible = $('#responsive-menu').is(':visible');
          $button.attr('aria-expanded', String(menuVisible));
          App.ResponsiveMenu.updateBackgroundInert(menuVisible);

          if (menuVisible) {
            var focusable = App.ResponsiveMenu.getFocusableElements();
            if (focusable.length > 0) {
              focusable[0].focus();
            }
          }
        }, 0);
      });

      $("body").on("mouseenter", ".main-menu li.nav-element[aria-expanded]", function() {
        if (!recentTouch) {
          $(this).attr("aria-expanded", "true");
          $(this).children("[data-navbar-toggle]").attr("aria-expanded", "true");
        }
      });

      $("body").on("mouseleave", ".main-menu li.nav-element[aria-expanded]", function() {
        if (!recentTouch) {
          $(this).attr("aria-expanded", "false");
          $(this).children("[data-navbar-toggle]").attr("aria-expanded", "false");
        }
      });
    },

    bindGlobalEvents: function() {
      if (this.globalEventsBound) return;

      this.globalEventsBound = true;

      $(document).on("click", function(event) {
        if (!$(event.target).closest("[data-navbar]").length) {
          $("[data-navbar] li.nav-element[aria-expanded='true']").attr("aria-expanded", "false");
          $("[data-navbar] button[aria-expanded='true']").attr("aria-expanded", "false");
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

      document.addEventListener("touchstart", function() {
        recentTouch = true;
        setTimeout(function() { recentTouch = false; }, 500);
      }, true);
    },
  };
}).call(this);

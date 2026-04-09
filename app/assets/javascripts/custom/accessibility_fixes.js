(function() {
  "use strict";
  App.AccessibilityFixes = {

    updateMjAccordion: function() {
      $('.mj_accordion_item').addClass('js-prevent-key-scroll focusable')
      $('.mj_accordion_item').attr('tabindex', '0')
      $('.mj_accordion_item').attr('aria-label', 'Accordion Menü Inhaltsblock')
      $('.mj_accordion_content').attr('aria-live', 'polite')

      $('.mj_accordion_item').each( function() {
        $(this).attr('aria-expanded', $(this).hasClass('active'))
      })
    },

    clickLabelAdjasentButton: function($label) {
      var inputFileId = $label.attr('for')
      var inputFileIdString = '#' + inputFileId
      $(inputFileIdString).trigger('click');
    },

    initialize: function() {
      App.AccessibilityFixes.updateMjAccordion();

      $('body').on('keyup', '.js-access-label-to-button', function(event) {
        if (event.which === 13) {
          event.preventDefault()
          var $label = $(this)
          App.AccessibilityFixes.clickLabelAdjasentButton($label)
        }
      })

      $('body').on('keyup', '.js-access-toggle-projekt-filter-checkbox', function(event) {
        if ( event.which === 32 || // space
             event.which === 13  ) { // enter
          $(this).siblings('input').trigger('click');
        }
      })

      $('body').on('keydown', '.js-prevent-key-scroll', function(event) {
        if ( event.which === 37 ||  // left arrow
             event.which === 38 ||  // up arrow
             event.which === 39 ||  // right arrow
             event.which === 40 ||  // down arrow
             event.which === 32     // space
           ) {
          event.preventDefault();
        }
      })

      $('body').on('keyup', '.js-icon-toggle-child-projekts', function(event) {
        event.preventDefault();
        var $toggleArrow = $(this);
        var arrowExpanded = $toggleArrow.attr('aria-expanded') == "true"

        if ( ( event.which === 38 && arrowExpanded  ) || // up arrow and expanded
             ( event.which === 40 && !arrowExpanded ) ) { // down arrow and closed
          App.Projekts.toggleChildrenInSidebar($toggleArrow.closest('li'))
        }
      })

      $('body').on('keyup', '.js-icon-toggle-budget-phases', function(event) {
        event.preventDefault();
        var $toggleArrow = $(this);
        var $phase = $(this).closest('.sidebar-projekt-phase')
        var arrowExpanded = $toggleArrow.attr('aria-expanded') == "true"

        if ( ( event.which === 38 && arrowExpanded  ) || // up arrow and expanded
             ( event.which === 40 && !arrowExpanded ) ) { // down arrow and closed

          $toggleArrow.attr('aria-expanded', !arrowExpanded)
          $phase.attr('aria-expanded', !arrowExpanded)
        }
      });

      $('body').on('keyup', '.js-access-top-level-menu', function(event) {
        if ( !$(event.target).hasClass('js-access-top-level-menu') ) { return false }

        var $menuItem = $(this);
        var menuItemExpanded = $menuItem.attr('aria-expanded') == "true"

        if ( event.which === 9 && this === document.activeElement  ) { // tab button pressed
          $('ul.nav-flyout-block').hide()
        }

        if ( event.which === 38 && menuItemExpanded && $(document.activeElement).hasClass('js-access-top-level-menu')) { // up arrow and menu expanded
          $menuItem.attr('aria-expanded', false)
          $menuItem.children('ul.nav-flyout-block').hide()
        }

        if ( event.which === 40 && !menuItemExpanded && $(document.activeElement).hasClass('js-access-top-level-menu')) { // down arrow and menu closed
          $menuItem.attr('aria-expanded', true)
          $menuItem.children('ul.nav-flyout-block').show()
        }

        if ( event.which === 40 && menuItemExpanded && $(document.activeElement).hasClass('js-access-top-level-menu')) { // down arrow and menu expanded
          $menuItem.children('ul.nav-flyout-block').first().children('li.flyout-item').first().focus()
        }

        if ( event.which === 39 && $(document.activeElement).hasClass('js-access-top-level-menu')) { // right arrow
          $menuItem.attr('aria-expanded', false)
          $menuItem.children('ul.nav-flyout-block').hide()
          $menuItem.next().focus()
        }

        if ( event.which === 37 && $(document.activeElement).hasClass('js-access-top-level-menu')) { // left arrow
          $menuItem.attr('aria-expanded', false)
          $menuItem.children('ul.nav-flyout-block').hide()
          $menuItem.prev().focus()
        }

        if ( event.which === 27 ) { // escape
          $menuItem.attr('aria-expanded', false)
          $menuItem.children('ul.nav-flyout-block').hide()
        }

        if ( event.which === 13 && $(document.activeElement).hasClass('js-access-top-level-menu') ) {

          if ( $(document.activeElement).find('.flyout-item-name > a').length ) {
            $(document.activeElement).find('.flyout-item-name > a').first()[0].click()

          } else if ( $(document.activeElement).children("a.home-items-icon").length  ) {
            $(document.activeElement).children("a.home-items-icon").first()[0].click()

          } else if ( $(document.activeElement).children("a.notifications").length  ) {
            $(document.activeElement).children("a.notifications").first()[0].click()

          }
        }

      })

      // Keyboard navigation for [data-navbar] items
      $('body').on('keydown', '[data-navbar] li.nav-element.top-level-item', function(event) {
        var $li = $(this);
        var expanded = $li.attr('aria-expanded') === 'true';

        if (event.which === 40) { // down arrow
          event.preventDefault();
          if (!expanded && $li.children('ul.nav-flyout-block').length) {
            $li.attr('aria-expanded', 'true');
            $li.children('button[data-navbar-toggle]').attr('aria-expanded', 'true');
            $li.find('> ul.nav-flyout-block > li:first-child > a').focus();
          } else if (expanded) {
            $li.find('> ul.nav-flyout-block > li:first-child > a').focus();
          }
        }

        if (event.which === 38) { // up arrow
          event.preventDefault();
          if (expanded) {
            $li.attr('aria-expanded', 'false');
            $li.children('button[data-navbar-toggle]').attr('aria-expanded', 'false');
          }
        }

        if (event.which === 39) { // right arrow
          event.preventDefault();
          var $nextLi = $li.next('li.nav-element.top-level-item');
          if ($nextLi.length) $nextLi.children('a').first().focus();
        }

        if (event.which === 37) { // left arrow
          event.preventDefault();
          var $prevLi = $li.prev('li.nav-element.top-level-item');
          if ($prevLi.length) $prevLi.children('a').first().focus();
        }

        if (event.which === 27) { // escape
          event.preventDefault();
          $li.attr('aria-expanded', 'false');
          $li.children('button[data-navbar-toggle]').attr('aria-expanded', 'false');
        }
      });

      $('body').on('keydown', '[data-navbar] li.nav-element.flyout-item', function(event) {
        event.stopPropagation(); // don't bubble to top-level handler
        var $li = $(this);
        var expanded = $li.attr('aria-expanded') === 'true';

        if (event.which === 40) { // down arrow
          event.preventDefault();
          var $nextLi = $li.next('li.flyout-item');
          if ($nextLi.length) $nextLi.children('a').first().focus();
        }

        if (event.which === 38) { // up arrow
          event.preventDefault();
          var $prevLi = $li.prev('li.flyout-item');
          if ($prevLi.length) {
            $prevLi.children('a').first().focus();
          } else {
            var $parentLi = $li.closest('ul.nav-flyout-block').closest('li.nav-element');
            $parentLi.attr('aria-expanded', 'false');
            $parentLi.children('button[data-navbar-toggle]').attr('aria-expanded', 'false');
            $parentLi.children('a').first().focus();
          }
        }

        if (event.which === 39) { // right arrow — open nested flyout
          if ($li.children('ul.nav-flyout-block').length) {
            event.preventDefault();
            $li.attr('aria-expanded', 'true');
            $li.children('button[data-navbar-toggle]').attr('aria-expanded', 'true');
            $li.find('> ul.nav-flyout-block > li:first-child > a').focus();
          }
        }

        if (event.which === 37) { // left arrow — close flyout, return to parent
          event.preventDefault();
          var $parentLi = $li.closest('ul.nav-flyout-block').closest('li.nav-element');
          $parentLi.attr('aria-expanded', 'false');
          $parentLi.children('button[data-navbar-toggle]').attr('aria-expanded', 'false');
          $parentLi.children('a').first().focus();
        }

        if (event.which === 27) { // escape — close all flyouts
          event.preventDefault();
          $('[data-navbar] li.nav-element[aria-expanded="true"]').attr('aria-expanded', 'false');
          $('[data-navbar] button[aria-expanded="true"]').attr('aria-expanded', 'false');
          $li.closest('[data-navbar]').find('li.top-level-item > a').first().focus();
        }
      });

      // ESC key dismisses hovered menu submenus (WCAG 1.4.13)
      $(document).on('keydown', function(event) {
        if (event.which !== 27) return;

        var $hoveredItems = $('.main-menu li.nav-element:hover');

        if ($hoveredItems.length) {
          event.preventDefault();
          $hoveredItems.addClass('-esc-dismissed');
        }
      });

      $('body').on('mouseleave', '.main-menu li.nav-element.-esc-dismissed', function() {
        $(this).removeClass('-esc-dismissed');
      });

      $('body').on('keyup', '.js-access-flyout-menu-item', function(event) {
        event.preventDefault();
        var $menuItem = $(this);
        var menuItemExpanded = $menuItem.attr('aria-expanded') == "true"

        if ( event.which === 39 && !menuItemExpanded && $(document.activeElement).children("ul.nav-flyout-block").length ) { // right arrow
          $menuItem.attr('aria-expanded', true)
          $menuItem.children('ul.nav-flyout-block').show()
        }

        if ( event.which === 39 && menuItemExpanded ) { // right arrow
          $menuItem.find('li.flyout-item').first().focus()
        }

        if ( event.which === 37 && menuItemExpanded ) { // left arrow
          $menuItem.attr('aria-expanded', false)
          $menuItem.children('ul.nav-flyout-block').hide()
        }

        if ( event.which === 37 && !menuItemExpanded ) { // left arrow
          $menuItem.parent().closest('li.flyout-item').focus()
          $menuItem.parent().closest('li.flyout-item').attr('aria-expanded', false)
          $menuItem.parent().closest('li.flyout-item').children('ul.nav-flyout-block').hide()
        }

        if ( event.which === 38 && !menuItemExpanded && $(document.activeElement).hasClass('js-access-flyout-menu-item') )  { // up arrow
          if ( $menuItem.parent().parent().hasClass('js-access-top-level-menu') && !$menuItem.prev().length ) {
            $(document.activeElement).parent().parent().focus();
          } else {
            $menuItem.prev().focus()
          }
        }

        if ( event.which === 40 && !menuItemExpanded && $(document.activeElement).hasClass('js-access-flyout-menu-item') )  { // down arrow
          $menuItem.next().focus()
        }

        if ( event.which === 13 && $(document.activeElement).hasClass('js-access-flyout-menu-item') ) { // click on link
          if ( $(document.activeElement).children('.projekt-name-group').find('a[tabindex="-1"]').length ) {
            $(document.activeElement).children('.projekt-name-group').find('a[tabindex="-1"]').first()[0].click()
          } else if ( $(document.activeElement).children('a[tabindex="-1"]').length ) {
            $(document.activeElement).children('a[tabindex="-1"]').first()[0].click()
          }
        }

      })

    }
  };
}).call(this);

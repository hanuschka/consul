(function() {
  "use strict";
  App.CustomPages = {
    initialize: function() {
      var tabFilterSubnav = document.getElementById('filter-subnav')
      var questionTab = document.querySelector('.page-subnav-tab.is-active')

      if (tabFilterSubnav && questionTab) {
        var scrollLeftWidth = $('.page-subnav-tab.is-active').offset().left - tabFilterSubnav.clientWidth

        if (scrollLeftWidth > 0) {
          $('#left-arrow-control').removeClass('disabled')
          $('#filter-subnav').animate( { scrollLeft: scrollLeftWidth + 400 }, 10 );
        }
      }

      $("body").off("click.budgetPhasesToggle").on("click.budgetPhasesToggle", ".js-icon-toggle-budget-phases", function(event) {
        event.preventDefault();
        event.stopPropagation();
        var $button = $(this);
        var $phase = $button.closest('.sidebar-projekt-phase');
        // Source of truth: the BUTTON's aria-expanded. Falls back to phase's, then to "true".
        var current = $button.attr('aria-expanded') || $phase.attr('aria-expanded') || 'true';
        var newState = current === 'true' ? 'false' : 'true';

        $phase.attr('aria-expanded', newState);
        $button.attr('aria-expanded', newState);
      })

      $("body").on("click", ".js-left-arrow-control", function(event) {
        $('#filter-subnav').animate( { scrollLeft: '-=240' }, 500 );

        var tabFilterSubnav = document.getElementById('filter-subnav')
        var maxScroll = tabFilterSubnav.scrollWidth - tabFilterSubnav.clientWidth

        if ( $('#filter-subnav').scrollLeft() <= 240 ) {
          $('#left-arrow-control').addClass('disabled')
        }

        if ( $('#filter-subnav').scrollLeft() != maxScroll) {
          $('#right-arrow-control').removeClass('disabled')
        }
      })

      $("body").on("click", ".js-right-arrow-control", function(event) {
        $('#filter-subnav').animate( { scrollLeft: '+=240' }, 500 );

        var tabFilterSubnav = document.getElementById('filter-subnav')
        var maxScroll = tabFilterSubnav.scrollWidth - tabFilterSubnav.clientWidth

        if ( maxScroll != 0 ) {
          $('#left-arrow-control').removeClass('disabled')
        }

        if ( maxScroll <= $('#filter-subnav').scrollLeft() + 240 ) {
          $('#right-arrow-control').addClass('disabled')
        }

      })

      $("body").on("click", ".spinner-placeholder ul.pagination li a", function(event) {
        $(".spinner-placeholder").addClass("show-loader")
      })
    }
  }
}).call(this);

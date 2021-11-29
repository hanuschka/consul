(function() {
  "use strict";
  App.ProjektSelector = {

    toggleProjektGroup: function(selector) {
      if (selector.dataset.target) {
        var target_projekt_group_id = selector.dataset.target
        $(target_projekt_group_id).toggle()
      }
    },

    selectProjekt: function($projekt) {
      var $selectedProjekt = $projekt.clone().removeClass('js-select-projekt')
      var projektId = $projekt.data('projektId')
      var $currentProjektSelector = $projekt.closest('.projekt-selector')
      var $nextProejektSelector = $currentProjektSelector.nextAll('.projekt-selector').first()
      var $nextSpacer = $currentProjektSelector.next()


      App.ProjektSelector.resetNextSelectors($currentProjektSelector)

      // replace placeholder with projekt
      $currentProjektSelector.find('.selected-projekt').first().hide();
      $currentProjektSelector.children('.projekt').remove();
      $currentProjektSelector.prepend( $selectedProjekt )

      // show next selector
      if ( $selectedProjekt.data('projektSelectableChildren') ) {
        $nextSpacer.css('visibility', 'visible')
        $nextProejektSelector.css('visibility', 'visible')
        $nextProejektSelector.attr('data-target', '#group-for-' + projektId)
        $nextProejektSelector.children('.projekt_group').hide()
        $('#group-for-' + projektId).show();
      }

      // update selected projekt
      if ( $selectedProjekt.data('projektSelectable') ) {
        App.ProjektSelector.resetSelectedProjectStyles();

        $('[id$="projekt_id"]').val(projektId)

        $selectedProjekt.css('background-color', '#004A83')
        $selectedProjekt.css('color', '#FFF')
        $selectedProjekt.find('.projekt-icon .fas').css('color', '#FFF')
        $selectedProjekt.closest('.projekt-selector').css('color', '#FFF')
        App.ProjektSelector.addNextProjektPlaceholder($nextProejektSelector, "(optional)")
        App.ProjektSelector.replaceProjektMapOnProposalCreation($selectedProjekt)

      } else {
        App.ProjektSelector.resetSelectedProjectStyles();
        $('[id$="projekt_id"]').val('')
        $selectedProjekt.css('background-color', '#CEE9F9')
        App.ProjektSelector.addNextProjektPlaceholder($nextProejektSelector, "(verpflichtend)")
      }
    },

    addNextProjektPlaceholder: function( $nextProejektSelector, text ) {
      var indexOfProjektSelector = $('.projekt-selector').index($nextProejektSelector)

      if (indexOfProjektSelector == 1) {
        $nextProejektSelector.find('.selected-projekt-placeholder').html("Wähle Kategorie " + text)
      } else if (indexOfProjektSelector == 2) {
        $nextProejektSelector.find('.selected-projekt-placeholder').html("Wähle Unterkategorie " + text)
      }
    },

    resetSelectedProjectStyles: function() {
      $('.projekt-selector > .projekt').css('background-color', '#CEE9F9')
      $('.projekt-selector > .projekt').css('color', '#0a0a0a')
      $('.projekt-selector').css('color', '#0a0a0a')
      $('.projekt-selector').children('.projekt').find('.projekt-icon .fas').css('color', '#222')
    },

    resetNextSelectors: function($selector) {
      $selector.nextAll().each( function() {
        $(this).css('visibility', 'hidden');
        $(this).find('.selected-projekt').show();
        $(this).children('.projekt').remove();
      })
    },

    replaceProjektMapOnProposalCreation: function($projekt) {
      if ( $projekt.data('showMap') ) {
        App.Map.maps[0].setView([$projekt.data('latitude'), $projekt.data('longitude')], $projekt.data('zoom')).invalidateSize()
      }
    },

    preselectProjekt: function(projektId) {
      // get preselcted projekt id
      var url = new URL(window.location.href);
      var selectedProjektId = url.searchParams.get('projekt');

      // get ordered array of parent projekts
      var projektIdsToShow = [selectedProjektId]
      var $selectedProjekt = $('#projekt_' + selectedProjektId)
      while ( $selectedProjekt.data('parentId') ) {
        projektIdsToShow.unshift( $selectedProjekt.data('parentId') )
        $selectedProjekt = $('#projekt_' + $selectedProjekt.data('parentId'))
      }

      // show projekts staring with top parent
      $.each(projektIdsToShow, function(index, projektId) {
        console.log(projektId)
        var $selectedProjekt = $('#projekt_' + projektId)
        App.ProjektSelector.selectProjekt($selectedProjekt);
        $selectedProjekt.closest('.projekt_group').hide();
      });
    },

    initialize: function() {
      $("body").on("click", ".js-toggle-projekt-group", function(event) {
        App.ProjektSelector.toggleProjektGroup(this);
      });

      $("body").on("click", ".js-select-projekt", function(event) {
        App.ProjektSelector.selectProjekt($(this));
      });

      $(".js-new-resource").on("click", function(event) {
        if ( $(event.target).closest('.js-toggle-projekt-group').length == 0 ) {
          $('.projekt_group').hide();
        }
      });

      App.ProjektSelector.preselectProjekt();
    }
  };
}).call(this);

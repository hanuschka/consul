(function() {
  "use strict";
  App.Projekts = {

    // Functions for selectors in form

    toggleChildProjekts: function($label) {
      var projektId = $label.data()['projektId']
      var $childrenProjektsGroup = $(`[data-parent="${projektId}"]`)

      if ( $childrenProjektsGroup.is(":hidden") ) {
        App.Projekts.resetSelectedChildren($label);
        $childrenProjektsGroup.show()
      } else {
        App.Projekts.resetSelectedChildren($label);
      }
    },

    resetSelectedChildren: function($label) {
      var $currentProjektGroup = $label.parent();
      var $currentColumn = $label.parent().parent()

      $currentProjektGroup.find('label').each(function() {
        App.Projekts.restyleHidingElements($(this));
      });

      $currentColumn.nextAll().each(function() {
        $(this).find(".projekt-group").each( function() {
          $(this).find('label').each(function() {
            App.Projekts.restyleHidingElements($(this));
          })
          $(this).hide();
        })
      })
    },


    restyleHidingElements: function($label) {
      $label.css('background', '#fff')
      $label.css('color', '#C6C6C6');
      $label.find('.checkmark').css('border-color', '#C6C6C6')

      if ( $label.find('input').first().is(':checked') ) {
        App.Projekts.showCheckmark($label);
      };
    },

    styleSelectedProjekt: function($label) {
      $label.css('background', '#ECF2FB');
      $label.css('color', '#06408E');
      $label.find('.checkmark').css('border', '1.5px solid #06408E')

      if ( $label.find('input').first().is(':checked') ) {
        $label.find('.checkmark').css('background', '#06408E')
        $label.find('.checkmark-before').show()
      };
    },

    hideCheckmark: function($label) {
      $label.find('.checkmark-before').hide()
      $label.find('.checkmark').css('background', 'inherit')
      $label.find('.checkmark').css('border', '1.5px solid #C6C6C6')
      $label.css('color', '#C6C6C6');
    },

    showCheckmark: function($label) {
      $label.find('.checkmark-before').show()
      $label.find('.checkmark').css('background', '#06408E')
      $label.find('.checkmark').css('border', '1.5px solid #06408E')
      $label.css('color', '#06408E');
    },

    removeCheckboxChip: function(projektId) {
      var $projektChip = $(`#projekt-chip-${projektId}`).parent();
      $projektChip.remove();
    },

    addCheckboxChip: function($label) {
      var projektId = 'projekt-chip-' + $label.data()['projektId']
      var projectName = $label.text()

      var chipToAdd = '<div class="projekt-chip">'

      chipToAdd += projectName
      chipToAdd += `<span id=${projektId} class="js-deselect-projekt close"></span>`
      chipToAdd += '</div>'


      $('#projekt-chips').append(chipToAdd)
    },

    // Functions for selectors in sidebar


    // Initializer
 
    initialize: function() {
      $("body").on("click", ".js-show-children-projekts", function(event) {
        event.preventDefault();
        if ( event.target.classList.contains('js-show-children-projekts') ) {
          var $label = $(this)
          App.Projekts.toggleChildProjekts($label);
          App.Projekts.styleSelectedProjekt($label);
          return false;
        }
      });

      $("body").on("click", ".js-select-projekt", function() {
        var $label = $(this).parent()
        var $checkbox = $label.find("input").first()
        var projektId = $(this).parent().data()['projektId']

        if ( $checkbox.is(":checked") ) {
          $checkbox.prop( "checked", false);
          App.Projekts.hideCheckmark($label);
          App.Projekts.removeCheckboxChip(projektId)
        } else {
          $checkbox.prop( "checked", true );
          App.Projekts.showCheckmark($label);
          App.Projekts.addCheckboxChip($label)
        }
      });

      $("body").on("click", ".js-deselect-projekt", function() {

        var projektId = this.id.split('-').pop()
        var $correspondingLabel = $(`[data-projekt-id="${projektId}"]`)

        App.Projekts.hideCheckmark($correspondingLabel);
        App.Projekts.removeCheckboxChip(projektId);
      });
    }
  };
}).call(this);

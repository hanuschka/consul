(function() {
  App.Shared = {
    debounce: function(func, wait) {
      var timer;
      return function() {
        var context = this;
        var args = Array.prototype.slice.call(arguments);
        if (timer) clearTimeout(timer);
        timer = setTimeout(function() {
          func.apply(context, args);
        }, wait);
      };
    },

    toggleElementsWithClass: function($toggler) {
      togglerType = $toggler.prop("type");
      $targets = $($toggler.data("target"));
      toggleClass = $toggler.data("toggle-class");

      console.log("togglerType: " + togglerType);

      if ( togglerType === "checkbox" ) {
        if ( $toggler.is(":checked") ) { $targets.addClass(toggleClass)} else { $targets.removeClass(toggleClass) }
      }
    },

    initialize: function() {
      $("body").on("click", ".js-class-toggler", function() {
        App.Shared.toggleElementsWithClass($(this));
      });

      console.log("initialize");
      $(".js-class-toggler").each(function() {
        console.log("each");
        App.Shared.toggleElementsWithClass($(this));
      });
    }
  };
}).call(this);

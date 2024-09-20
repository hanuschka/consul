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
    }
  };
}).call(this);

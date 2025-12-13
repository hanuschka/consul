(function() {
  App.Features = {
    isEnabled: function(featureName) {
      const meta = document.querySelector('meta[name="' + featureName + '"]');
      return meta && meta.content === 'true';
    }
  };
}).call(this);

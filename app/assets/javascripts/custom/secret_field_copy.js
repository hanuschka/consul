(function() {
  "use strict";
  App.SecretFieldCopy = {
    initialize: function() {
      const toggleBtn = $('#toggle-token-btn');
      const copyBtn = $('#copy-token-btn');
      const tokenDisplay = $('#auth-token-display');

      if (toggleBtn.length === 0 || copyBtn.length === 0 || tokenDisplay.length === 0) return;

      const fullToken = toggleBtn.data('token');
      const originalCopyIcon = copyBtn.html();
      let isVisible = false;
      let copyTimeoutId = null;

      toggleBtn.on('click', function(event) {
        event.preventDefault();
        isVisible = !isVisible;

        const iconElement = toggleBtn.find('i');

        if (isVisible) {
          tokenDisplay.text(fullToken);
          toggleBtn.attr('title', toggleBtn.data('hideTitle'));
          iconElement.removeClass('fa-eye').addClass('fa-eye-slash');
        } else {
          tokenDisplay.text('••••••••••••••••');
          toggleBtn.attr('title', toggleBtn.data('showTitle'));
          iconElement.removeClass('fa-eye-slash').addClass('fa-eye');
        }
      });

      copyBtn.on('click', function(event) {
        event.preventDefault();

        if (copyTimeoutId) {
          clearTimeout(copyTimeoutId);
        }

        navigator.clipboard.writeText(fullToken).then(function() {
          copyBtn.html('<span class="icon-check"></span>');
          copyTimeoutId = setTimeout(function() {
            copyBtn.html(originalCopyIcon);
            copyTimeoutId = null;
          }, 2000);
        })
      });
    }
  };
}).call(this);

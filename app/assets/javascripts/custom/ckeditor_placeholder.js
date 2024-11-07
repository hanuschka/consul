(function() {
  "use strict";
  App.CkeEditorPlaceholder = {
    initialize: function() {
      var form = document.querySelector(".js-rich-text-form");

      if (!form) {
        return;
      }

      // Add a submit event listener to the form
      form.addEventListener("submit", function(event) {
        // Prevent the form from submitting immediately
        event.preventDefault();

        // Get the current content of the CKEditor
        document.querySelectorAll( '.ck-editor__editable' ).forEach( function(editor) {
          existingPlaceholderElement = editor.ckeditorInstance.editing.view.document.getRoot( 'main' );

          if (existingPlaceholderElement.placeholder) {
            existingPlaceholderElement.placeholder = "";
          }
        })

        form.submit();
      });
    }
  };
}).call(this);

(function() {
  "use strict";
  App.CkeEditorPlaceholder = {
    initialize: function() {
      const form = document.querySelector(".js-rich-text-form");

      if (!form) {
        return;
      }

      // Add a submit event listener to the form
      form.addEventListener("submit", function(event) {
        // Prevent the form from submitting immediately
        event.preventDefault();

        App.CkeEditorPlaceholder.clearPlaceholders();
        App.CkeEditorPlaceholder.preserveSubmitter(form, event.submitter);

        form.submit();
      });
    },

    // The editors keep rendering their placeholder into the submitted value,
    // so it has to be emptied before the form is sent.
    clearPlaceholders: function() {
      // Get the current content of the CKEditor
      document.querySelectorAll(".ck-editor__editable").forEach(function(editor) {
        const root = editor.ckeditorInstance.editing.view.document.getRoot("main");

        if (root.placeholder) {
          root.placeholder = "";
        }
      });
    },

    // form.submit() sends no submitter, so a named submit button would lose
    // its name/value pair. Carry it over as a hidden field instead.
    preserveSubmitter: function(form, submitter) {
      if (!submitter || !submitter.name) {
        return;
      }

      const field = document.createElement("input");
      field.type = "hidden";
      field.name = submitter.name;
      field.value = submitter.value;

      form.appendChild(field);
    }
  };
}).call(this);

document.addEventListener('turbolinks:load', function() { 

  var plzCheckBox = document.querySelector('input[id$="_plz_consent"]')
  var plzField = document.querySelector('input[id$="_plz"]')

  if ( plzCheckBox ) {
    plzCheckBox.addEventListener('change', function() {
      if (this.checked) {
        plzField.disabled = false;
      } else {
        plzField.disabled = true;
      }
    })
  }
});

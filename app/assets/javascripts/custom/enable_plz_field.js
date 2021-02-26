document.addEventListener('turbolinks:load', function() { 

  var plzCheckBox = document.getElementById('user_plz_consent')
  var plzField = document.getElementById('user_plz')

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

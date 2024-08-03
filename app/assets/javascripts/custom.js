//= require custom/textarea_autoexpand
//= require custom/mjAccordion.js
//= require turbolinks
//= require glightbox/dist/js/glightbox.min.js

function initializeMjAccordion() {
  "use strict";
  $(".mj_accordion").mjAccordion();
}

function initComponents() {
  "use strict";

  initializeMjAccordion();
  App.LivesteamLivequestion.initialize();
  App.CollapseTextComponent.initialize();
}

$(function() {
  "use strict";

  $(document).ready(function() {
    initComponents();
  });

  $(document).on("turbolinks:load", function() {
    initComponents();
  });
});

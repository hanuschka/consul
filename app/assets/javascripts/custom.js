//= require custom/textarea_autoexpand
//= require custom/mjAccordion.js
//= require turbolinks
//= require photoswipe/dist/umd/photoswipe-lightbox.umd.min.js
//= require photoswipe/dist/umd/photoswipe.umd.min.js

function initializeMjAccordion() {
  "use strict";
  $(".mj_accordion").mjAccordion();
}

function initComponents() {
  "use strict";

  initializeMjAccordion();
  App.LivesteamLivequestion.initialize();
  App.CollapseTextComponent.initialize();
  App.ImageGallery.initialize();
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

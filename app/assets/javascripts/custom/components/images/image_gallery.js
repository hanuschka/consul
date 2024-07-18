(function() {
  "use strict";
  App.ImageGallery = {
    initialize: function() {
      var lightbox = new window.PhotoSwipeLightbox({
        gallery: '.image-gallery-with-ligthbox',
        children: 'a',
        showAnimationDuration: 0,
        hideAnimationDuration: 0,
        pswpModule: window.PhotoSwipe
      });
      lightbox.init();
    },
  };
}).call(this);

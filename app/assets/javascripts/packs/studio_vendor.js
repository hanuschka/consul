// Vendor prerequisites for packs/studio.js in contexts that don't load the
// legacy application.js bundle (currently the /adm newsletter edit page).
// Must be included BEFORE packs/studio.js. Never load this on legacy
// frontend pages — application.js already provides jQuery, and a second
// jQuery would detach all plugins registered on the first one.
//
//= require jquery
//= require cropperjs/dist/cropper

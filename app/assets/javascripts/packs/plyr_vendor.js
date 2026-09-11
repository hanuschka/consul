// Plyr, served from our own host instead of cdn.plyr.io so that playing a
// video never sends the visitor's IP to a third party. GLightbox pulls this
// in on the first video slide; both of its Plyr URLs are overridden at the
// call sites, which also repoint Plyr's own iconUrl and blankVideo defaults.
//
// The UMD build, so it attaches window.Plyr — the name GLightbox waits for.
//
//= require plyr/dist/plyr.min

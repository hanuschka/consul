// Mapbox GL JS and its draw/geocoder plugins, served from our own host
// instead of api.mapbox.com so that opening a page never sends the visitor's
// IP to a third party before consent. All UMD builds, so they attach
// window.mapboxgl, window.MapboxDraw and window.MapboxGeocoder.
//
// Loaded lazily by both packs — the bundle is close to a megabyte, so pages
// without a Mapbox map must not pay for it.
//
//= require mapbox-gl/dist/mapbox-gl
//= require @mapbox/mapbox-gl-draw/dist/mapbox-gl-draw
//= require @mapbox/mapbox-gl-geocoder/dist/mapbox-gl-geocoder.min

// Leaflet and its plugins, served from our own host instead of unpkg /
// jsDelivr so that opening a page never sends the visitor's IP to a third
// party before consent. All UMD builds, so they attach window.L, and
// window.GeoSearch for the geocoder control.
//
// NOTE: the main app does not use this — application.js already bundles the
// same files. This pack exists for the /adm pack, whose map adapters pull it
// in lazily so that pages without a map never download it.
//
//= require leaflet/dist/leaflet
//= require leaflet.markercluster/dist/leaflet.markercluster
//= require leaflet.locatecontrol/dist/L.Control.Locate.min
//= require leaflet-geosearch/dist/geosearch.umd
//= require leaflet-gesture-handling/dist/leaflet-gesture-handling
//= require @geoman-io/leaflet-geoman-free/dist/leaflet-geoman.min
//= require Leaflet.Deflate/dist/L.Deflate
//= require leaflet.heat/dist/leaflet-heat

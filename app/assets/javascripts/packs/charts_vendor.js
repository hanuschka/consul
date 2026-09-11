// Chart.js and its datalabels plugin, served from our own host instead of a
// public CDN so that opening a page never sends the visitor's IP to a third
// party before consent. Both are the UMD builds, so they attach window.Chart
// and window.ChartDataLabels for the legacy frontend chart code.
//
// NOTE: the /adm pack does not use this — app/javascript/controllers/adm/
// charts_controller.js imports chart.js and esbuild bundles it there.
//
//= require chart.js/dist/chart.umd.min.js
//= require chartjs-plugin-datalabels/dist/chartjs-plugin-datalabels.min.js

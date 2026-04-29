Rails.application.configure do
  config.x.masterportal = ActiveSupport::OrderedOptions.new
  config.x.masterportal.wms_url =
    ENV.fetch("MASTERPORTAL_WMS_URL",
              "https://mapservice.regensburg.de/cgi-bin/mapserv/regensburg/")
  config.x.masterportal.wms_layers =
    ENV.fetch("MASTERPORTAL_WMS_LAYERS", "biotonnen,barrierefrei,altglas").split(",")
  config.x.masterportal.oaf_endpoint =
    ENV.fetch("MASTERPORTAL_OAF_ENDPOINT",
              "https://mapservice.regensburg.de/cgi-bin/mapserv/regensburg/ogcapi/")
end

module PdfServices
  class BaseService < ApplicationService
    require "prawn"
    require "i18n"

    include Rails.application.routes.url_helpers
    include TextWithLinksHelper
  end
end

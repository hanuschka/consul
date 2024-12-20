module PdfServices
  class BaseService < ApplicationService

    include Rails.application.routes.url_helpers
    include TextWithLinksHelper
  end
end

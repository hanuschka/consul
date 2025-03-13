module CsvServices
  class BaseService < ApplicationService
    def sanitize_for_csv(value)
      value.to_s.gsub(/^[=+@-]/, "^")
    end

    def strip_tags(html_string)
      ActionView::Base.full_sanitizer.sanitize(html_string)
    end
  end
end

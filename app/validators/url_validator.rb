class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if url_valid?(value)

    record.errors.add(attribute, options[:message] || "must be a valid URL")
  end

  def url_valid?(url)
    url = URI.parse(url) rescue false
    url.kind_of?(URI::HTTP) || url.kind_of?(URI::HTTPS)
  end
end

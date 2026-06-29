class ServiceResult
  attr_reader :data, :error, :fallback_text, :error_details

  def initialize(success:, data: {}, error: nil, fallback_text: nil, error_details: {})
    @success = success
    @data = data
    @error = error
    @fallback_text = fallback_text
    @error_details = error_details
  end

  def success?
    @success
  end

  def self.success(data = {})
    new(success: true, data: data)
  end

  def self.failure(error:, fallback_text: nil, error_details: {})
    new(success: false, error: error, fallback_text: fallback_text, error_details: error_details)
  end

  def method_missing(method, *args)
    @data[method]
  end

  def respond_to_missing?(method, include_private = false)
    @data.key?(method) || super
  end
end

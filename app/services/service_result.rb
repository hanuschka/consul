class ServiceResult
  attr_reader :data, :error, :fallback_text

  def initialize(success:, data: {}, error: nil, fallback_text: nil)
    @success = success
    @data = data
    @error = error
    @fallback_text = fallback_text
  end

  def success?
    @success
  end

  def self.success(data = {})
    new(success: true, data: data)
  end

  def self.failure(error:, fallback_text: nil)
    new(success: false, error: error, fallback_text: fallback_text)
  end

  def method_missing(method, *args)
    @data[method]
  end

  def respond_to_missing?(method, include_private = false)
    @data.key?(method) || super
  end
end

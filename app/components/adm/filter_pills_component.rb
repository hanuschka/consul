class Adm::FilterPillsComponent < ApplicationComponent
  def initialize(headers:, params:)
    @headers = headers
    @params = params
  end

  def render?
    pills.any?
  end

  def pills
    @pills ||= @headers.flat_map { |header| header.filter_pills(@params) }
  end

  def href_for(pill)
    sanitized = sanitized_params
    if pill[:remove_key]
      sanitized.delete(pill[:remove_key].to_s)
    elsif pill[:remove_keys]
      pill[:remove_keys].each { |k| sanitized.delete(k.to_s) }
    elsif pill[:remove_array_key]
      key = pill[:remove_array_key].to_s
      remaining = Array(sanitized[key]).map(&:to_s).reject { |v| v == pill[:remove_array_value].to_s }
      if remaining.any?
        sanitized[key] = remaining
      elsif pill[:keep_empty_marker]
        sanitized[key] = [""]
      else
        sanitized.delete(key)
      end
    end
    helpers.url_for(sanitized)
  end

  private

    def sanitized_params
      hash = @params.respond_to?(:to_unsafe_h) ? @params.to_unsafe_h : @params.to_h
      hash = hash.deep_stringify_keys
      %w[controller action format].each { |k| hash.delete(k) }
      hash
    end
end

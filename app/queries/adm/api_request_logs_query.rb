class Adm::ApiRequestLogsQuery < ApplicationQuery
  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |scope| filter_by_url(scope) }
      .then { |scope| filter_by_http_method(scope) }
      .then { |scope| filter_by_response_status(scope) }
      .then { |scope| filter_by_api_client(scope) }
      .then { |scope| filter_by_start_date(scope) }
      .then { |scope| filter_by_end_date(scope) }
  end

  private

    attr_reader :base_scope, :params

    def filter_by_url(scope)
      return scope if params[:url].blank?

      pattern = "%#{escape_like(params[:url].strip)}%"

      scope.where("request_path ILIKE :pattern OR full_url ILIKE :pattern", pattern: pattern)
    end

    def filter_by_http_method(scope)
      return scope if params[:http_method].blank?

      scope.where(http_method: params[:http_method])
    end

    def filter_by_response_status(scope)
      return scope if params[:response_status].blank?

      scope.where(response_status: params[:response_status])
    end

    def filter_by_api_client(scope)
      return scope if params[:api_client_id].blank?

      scope.where(api_client_id: params[:api_client_id])
    end

    def filter_by_start_date(scope)
      date = parse_date(params[:start_date])
      return scope if date.blank?

      scope.where("created_at >= ?", date.beginning_of_day)
    end

    def filter_by_end_date(scope)
      date = parse_date(params[:end_date])
      return scope if date.blank?

      scope.where("created_at <= ?", date.end_of_day)
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value)
    rescue ArgumentError, TypeError
      nil
    end
end

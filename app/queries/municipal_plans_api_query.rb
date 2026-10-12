class MunicipalPlansApiQuery < ApplicationQuery
  class InvalidParameter < StandardError; end

  PRELOADS = [
    :translations, :links, :districts, :map_location,
    { topics: :translations }
  ].freeze

  def initialize(params = {})
    @params = params
  end

  # A consumer that syncs with changed_since also has to learn about Vorhaben that left the list,
  # so archived ones are included there and only there.
  def call
    scope = MunicipalPlan.released_versions
    scope = changed_since ? scope.publicly_visible.changed_since(changed_since) : scope.published

    MunicipalPlansQuery.new(scope, params.slice(:districts, :topics))
                       .call
                       .sorted
                       .with_last_status_change_at
                       .includes(PRELOADS)
  end

  private

    attr_reader :params

    def changed_since
      value = params[:changed_since]
      return if value.blank?

      @changed_since ||= Time.zone.parse(value.to_s) || raise(ArgumentError)
    rescue ArgumentError
      raise InvalidParameter, "changed_since must be an ISO 8601 date or timestamp."
    end
end

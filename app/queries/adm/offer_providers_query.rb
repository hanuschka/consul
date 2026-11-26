class Adm::OfferProvidersQuery < ApplicationQuery
  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_name_search(r) }
      .then { |r| apply_sorting(r) }
  end

  private

    attr_reader :base_scope, :params

    def apply_name_search(scope)
      value = params[:name__search]
      return scope if value.blank?

      scope.where("offer_providers.name ILIKE ?", "%#{escape_like(value)}%")
    end

    def apply_sorting(scope)
      direction = params[:sort_by].to_s == "name" && params[:sort_direction].to_s.casecmp("desc").zero? ? :desc : :asc

      scope.reorder(name: direction, id: direction)
    end
end

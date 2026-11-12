class Adm::OffersQuery < ApplicationQuery
  SORTABLE_FIELDS = %i[id title updated_at].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_title_search(r) }
      .then { |r| apply_sorting(r) }
  end

  private

    attr_reader :base_scope, :params

    def apply_title_search(scope)
      value = params[:title__search]
      return scope if value.blank?

      scope.where(id: Offer.translation_class
                        .where("title ILIKE ?", "%#{escape_like(value)}%")
                        .select(:offer_id))
    end

    def apply_sorting(scope)
      field = params[:sort_by]&.to_sym
      return scope.reorder(updated_at: :desc, id: :desc) unless SORTABLE_FIELDS.include?(field)

      direction = params[:sort_direction].to_s.casecmp("desc").zero? ? :desc : :asc
      return scope.sort_by_title(direction) if field == :title

      scope.reorder(field => direction, id: direction)
    end
end

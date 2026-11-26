class Adm::OffersQuery < ApplicationQuery
  SORTABLE_FIELDS = %i[id title updated_at].freeze
  FILTERABLE_FIELDS = %i[review_status visibility].freeze
  VISIBILITY_STATES = %w[visible suspended deactivated expired].freeze

  def initialize(base_scope, params = {})
    @base_scope = base_scope
    @params = params
  end

  def call
    base_scope
      .then { |r| apply_title_search(r) }
      .then { |r| apply_review_status_filter(r) }
      .then { |r| apply_visibility_filter(r) }
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

    def apply_review_status_filter(scope)
      values = filter_values(:review_status) & Offer.review_statuses.keys
      return scope if values.empty?

      scope.where(review_status: values)
    end

    def apply_visibility_filter(scope)
      values = filter_values(:visibility) & VISIBILITY_STATES
      return scope if values.empty?

      values.map { |state| visibility_scope(scope, state) }.reduce(:or)
    end

    def visibility_scope(scope, state)
      case state
      when "visible" then scope.published
      when "suspended" then scope.suspended
      when "deactivated" then scope.deactivated
      when "expired" then scope.expired
      end
    end

    def filter_values(field)
      filterable_params.fetch(field, []).compact_blank.map(&:to_s)
    end

    def filterable_fields
      FILTERABLE_FIELDS
    end

    def apply_sorting(scope)
      field = params[:sort_by]&.to_sym
      return scope.reorder(updated_at: :desc, id: :desc) unless SORTABLE_FIELDS.include?(field)

      direction = params[:sort_direction].to_s.casecmp("desc").zero? ? :desc : :asc
      return scope.sort_by_title(direction) if field == :title

      scope.reorder(field => direction, id: direction)
    end
end

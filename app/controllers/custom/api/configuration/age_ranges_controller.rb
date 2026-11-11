class Api::Configuration::AgeRangesController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %i[name].freeze
  IN_USE_MESSAGE = "is still used by projekt phases".freeze

  before_action :find_age_range, only: [:show, :update, :destroy]

  def index
    age_ranges = paginate(AgeRange.includes(:translations))

    render json: {
      data: { age_ranges: age_ranges.map { serialize(it) } },
      pagination: pagination_meta(age_ranges)
    }
  end

  def show
    render json: { data: { age_range: serialize(@age_range) } }
  end

  def create
    save_age_range(AgeRange.new, status: :created)
  end

  def update
    save_age_range(@age_range, status: :ok)
  end

  def destroy
    if age_range_in_use?(@age_range)
      return render_invalid_values("age_range" => [IN_USE_MESSAGE])
    end

    @age_range.destroy!

    head :no_content
  end

  private

    def find_age_range
      @age_range = AgeRange.includes(:translations).find(params[:id])
    end

    def age_range_params
      params.require(:age_range).permit(:order, :min_age, :max_age, :only_for_stats)
    end

    def translations_param
      params.dig(:age_range, :translations)
    end

    def save_age_range(age_range, status:)
      locales_error = unsupported_locales_error(translations_param)

      if locales_error
        return render_invalid_values(locales_error)
      end

      translations = permitted_translations(translations_param, TRANSLATED_ATTRIBUTES)
      age_range.assign_attributes(age_range_params)
      assign_translations(age_range, translations)

      if inverted_bounds?(age_range)
        return render_invalid_values("max_age" => ["must be greater than or equal to min_age"])
      end

      if save_with_translations(age_range, translations)
        render json: { data: { age_range: serialize(age_range) } }, status:
      else
        render_record_errors(age_range)
      end
    end

    def inverted_bounds?(age_range)
      age_range.min_age.is_a?(Integer) && age_range.max_age.is_a?(Integer) &&
        age_range.min_age > age_range.max_age
    end

    def age_range_in_use?(age_range)
      age_range.age_range_projekt_phases.exists? || age_range.age_restricted_projekt_phases.exists?
    end

    def serialize(age_range)
      {
        id: age_range.id,
        order: age_range.order,
        min_age: age_range.min_age,
        max_age: age_range.max_age,
        only_for_stats: age_range.only_for_stats,
        translations: serialize_translations(age_range, TRANSLATED_ATTRIBUTES)
      }
    end
end

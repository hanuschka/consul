# Only the name of a group is configuration. Kind and visibility are set once
# on create, because a group cannot exist without them; deleting a group would
# drop its members' assignments, so there is no destroy.
class Api::Configuration::IndividualGroupsController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %i[name].freeze

  before_action :find_individual_group, only: [:show, :update]

  def index
    individual_groups = paginate(IndividualGroup.includes(:translations).order(:id))

    render json: {
      data: { individual_groups: individual_groups.map { serialize(it) } },
      pagination: pagination_meta(individual_groups)
    }
  end

  def show
    render json: { data: { individual_group: serialize(@individual_group) } }
  end

  def create
    kind = params.dig(:individual_group, :kind).to_s

    if !IndividualGroup.kinds.key?(kind)
      return render_invalid_values("kind" => ["must be one of: #{IndividualGroup.kinds.keys.join(", ")}"])
    end

    individual_group = IndividualGroup.new(kind:, visible: create_params[:visible])

    save_individual_group(individual_group, status: :created)
  end

  def update
    save_individual_group(@individual_group, status: :ok)
  end

  private

    def find_individual_group
      @individual_group = IndividualGroup.includes(:translations).find(params[:id])
    end

    def create_params
      params.require(:individual_group).permit(:visible)
    end

    def translations_param
      params.require(:individual_group)[:translations]
    end

    def save_individual_group(individual_group, status:)
      locales_error = unsupported_locales_error(translations_param)

      if locales_error
        return render_invalid_values(locales_error)
      end

      translations = permitted_translations(translations_param, TRANSLATED_ATTRIBUTES)
      blank_name_locales = translations.select { |_locale, attributes| attributes["name"].blank? }.keys

      # The model checks the name in the request language only; a blank name
      # in another language would be stored empty, and an empty translation
      # does not fall back.
      if blank_name_locales.any?
        return render_invalid_values("name" => ["can't be blank (#{blank_name_locales.join(", ")})"])
      end

      assign_translations(individual_group, translations)

      if save_with_translations(individual_group, translations)
        render json: { data: { individual_group: serialize(individual_group) } }, status:
      else
        render_record_errors(individual_group)
      end
    end

    def serialize(individual_group)
      {
        id: individual_group.id,
        kind: individual_group.kind,
        visible: individual_group.visible,
        translations: serialize_translations(individual_group, TRANSLATED_ATTRIBUTES)
      }
    end
end

class Api::Configuration::BannersController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %w[title description].freeze

  ATTRIBUTE_DEFINITIONS = {
    "target_url" => TypedValueParser::Definition.new(type: :link),
    "post_started_at" => TypedValueParser::Definition.new(type: :date),
    "post_ended_at" => TypedValueParser::Definition.new(type: :date),
    "background_color" => TypedValueParser::Definition.new(type: :color),
    "font_color" => TypedValueParser::Definition.new(type: :color)
  }.freeze

  WRITABLE_ATTRIBUTES = (ATTRIBUTE_DEFINITIONS.keys + %w[web_section_ids translations]).freeze

  before_action :find_banner, only: [:show, :update, :destroy]

  def index
    banners = paginate(Banner.includes(:translations, :web_sections).order(post_started_at: :desc, id: :desc))

    render json: {
      data: { banners: banners.map { |banner| serialize(banner) } },
      pagination: pagination_meta(banners)
    }
  end

  def show
    render json: { data: { banner: serialize(@banner) } }
  end

  def create
    save_banner(Banner.new, status: :created)
  end

  def update
    save_banner(@banner, status: :ok)
  end

  def destroy
    @banner.destroy!

    head :no_content
  end

  private

    def find_banner
      @banner = Banner.find(params[:id])
    end

    def save_banner(banner, status:)
      attribute_values, errors = parsed_attributes
      translations = permitted_translations(banner_params[:translations], TRANSLATED_ATTRIBUTES)

      if errors.any?
        return render_invalid_values(errors)
      end

      banner.assign_attributes(attribute_values)
      assign_translations(banner, translations)

      if save_with_translations(banner, translations)
        render json: { data: { banner: serialize(banner.reload) } }, status:
      else
        render_translated_record_errors(banner)
      end
    end

    def banner_params
      params.require(:banner)
    end

    def parsed_attributes
      raw_attributes = banner_params.to_unsafe_h
      attribute_values, errors = parse_typed_attributes(raw_attributes, ATTRIBUTE_DEFINITIONS)
      errors.merge!(unknown_attribute_errors(raw_attributes, WRITABLE_ATTRIBUTES))
      errors.merge!(unsupported_locales_error(banner_params[:translations]) || {})

      if raw_attributes.key?("web_section_ids")
        web_section_ids, web_section_error = parsed_web_section_ids(raw_attributes["web_section_ids"])

        if web_section_error
          errors["web_section_ids"] = [web_section_error]
        else
          attribute_values["web_section_ids"] = web_section_ids
        end
      end

      [attribute_values, errors]
    end

    def parsed_web_section_ids(raw_ids)
      if !raw_ids.is_a?(Array) || !raw_ids.all? { |id| id.to_s.match?(/\A\d+\z/) }
        return [nil, "must be a list of web section ids"]
      end

      web_section_ids = raw_ids.map(&:to_i).uniq
      unknown_ids = web_section_ids - WebSection.where(id: web_section_ids).ids

      if unknown_ids.any?
        [nil, "contain unknown web sections: #{unknown_ids.join(", ")}"]
      else
        [web_section_ids, nil]
      end
    end

    def serialize(banner)
      {
        id: banner.id,
        target_url: banner.target_url,
        post_started_at: banner.post_started_at&.iso8601,
        post_ended_at: banner.post_ended_at&.iso8601,
        background_color: banner.background_color,
        font_color: banner.font_color,
        web_section_ids: banner.web_sections.map(&:id),
        active: active?(banner),
        translations: serialize_translations(banner, TRANSLATED_ATTRIBUTES),
        created_at: banner.created_at,
        updated_at: banner.updated_at
      }
    end

    def active?(banner)
      if banner.post_started_at.blank? || banner.post_ended_at.blank?
        false
      else
        Date.current.between?(banner.post_started_at, banner.post_ended_at)
      end
    end
end

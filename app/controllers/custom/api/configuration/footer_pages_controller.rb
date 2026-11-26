class Api::Configuration::FooterPagesController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %i[title subtitle content].freeze

  ATTRIBUTE_DEFINITIONS = {
    "slug" => TypedValueParser::Definition.new(type: :string),
    "status" => TypedValueParser::Definition.new(
      type: :select, options: ::SiteCustomization::Page::VALID_STATUSES
    ),
    "footer_position" => TypedValueParser::Definition.new(type: :integer, min: 1)
  }.freeze

  before_action :find_footer_page, only: [:show, :update]

  def index
    footer_pages = ::SiteCustomization::Page.footer_pages.includes(:translations)

    render json: { data: { footer_pages: footer_pages.map { serialize(it) } } }
  end

  def show
    render json: { data: { footer_page: serialize(@footer_page) } }
  end

  def update
    errors = {}
    attributes = parsed_attributes(footer_page_params, errors)
    translations = sanitize_translated_html(
      permitted_translations(translations_param, TRANSLATED_ATTRIBUTES), "content"
    )
    errors.merge!(unsupported_locales_error(translations_param) || {})

    if errors.any?
      return render_invalid_values(errors)
    end

    @footer_page.assign_attributes(attributes)
    assign_translations(@footer_page, translations)

    if save_with_translations(@footer_page, translations)
      render json: { data: { footer_page: serialize(@footer_page.reload) } }
    else
      render_translated_record_errors(@footer_page)
    end
  end

  private

    def find_footer_page
      @footer_page = ::SiteCustomization::Page.footer_pages.find(params[:id])
    end

    def footer_page_params
      params.require(:footer_page).permit(*ATTRIBUTE_DEFINITIONS.keys)
    end

    def translations_param
      params.dig(:footer_page, :translations)
    end

    def parsed_attributes(raw_attributes, errors)
      attribute_values, attribute_errors = parse_typed_attributes(raw_attributes.to_h, ATTRIBUTE_DEFINITIONS)
      errors.merge!(attribute_errors)

      attribute_values
    end

    def serialize(footer_page)
      {
        id: footer_page.id,
        footer_key: footer_page.footer_key,
        slug: footer_page.slug,
        url: footer_page.url,
        status: footer_page.status,
        footer_position: footer_page.footer_position,
        published_at: footer_page.published_at,
        translations: serialize_translations(footer_page, TRANSLATED_ATTRIBUTES),
        updated_at: footer_page.updated_at
      }
    end
end

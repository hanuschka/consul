class Api::Configuration::ContentCardsController < Api::Configuration::BaseController
  TRANSLATED_ATTRIBUTES = %w[title].freeze

  ATTRIBUTE_DEFINITIONS = {
    "active" => TypedValueParser::Definition.new(type: :boolean),
    "position" => TypedValueParser::Definition.new(type: :integer, min: 1)
  }.freeze

  SETTING_DEFINITION = TypedValueParser::Definition.new(type: :integer, min: 0)

  WRITABLE_ATTRIBUTES = (ATTRIBUTE_DEFINITIONS.keys + %w[settings translations]).freeze

  before_action :find_content_card, only: [:show, :update]

  # The cards of a homepage or landing page are created on first listing, as
  # /adm does when it shows them.
  def index
    content_cards =
      SiteCustomization::ContentCard
        .where(id: listed_content_cards.map(&:id))
        .includes(:translations)

    render json: { data: { content_cards: content_cards.map { |content_card| serialize(content_card) } } }
  end

  def show
    render json: { data: { content_card: serialize(@content_card) } }
  end

  def update
    attribute_values, errors = parsed_attributes
    translations = permitted_translations(content_card_params[:translations], TRANSLATED_ATTRIBUTES)

    if errors.any?
      return render_invalid_values(errors)
    end

    @content_card.assign_attributes(attribute_values)
    assign_translations(@content_card, translations)

    if save_with_translations(@content_card, translations)
      render json: { data: { content_card: serialize(@content_card.reload) } }
    else
      render_translated_record_errors(@content_card)
    end
  end

  private

    def find_content_card
      @content_card = SiteCustomization::ContentCard.find(params[:id])
    end

    def listed_content_cards
      if params[:landing_page_id].present?
        landing_page = ::SiteCustomization::Page.landing.find(params[:landing_page_id].to_s)
        SiteCustomization::ContentCard.get_or_create_for_landing_page(landing_page.id)
      else
        SiteCustomization::ContentCard.get_or_create_for_homepage
      end
    end

    def content_card_params
      params.require(:content_card)
    end

    def parsed_attributes
      raw_attributes = content_card_params.to_unsafe_h
      attribute_values = {}
      errors = (raw_attributes.keys - WRITABLE_ATTRIBUTES).index_with { ["is not a writable attribute"] }
      errors.merge!(unsupported_locales_error(content_card_params[:translations]) || {})

      ATTRIBUTE_DEFINITIONS.each do |name, definition|
        next if !raw_attributes.key?(name)

        result = TypedValueParser.parse(raw_attributes[name], definition)

        if result.valid?
          attribute_values[name] = result.value
        else
          errors[name] = [result.error]
        end
      end

      if attribute_values.key?("position")
        attribute_values["given_order"] = attribute_values.delete("position")
      end

      if raw_attributes.key?("settings")
        card_settings, setting_errors = parsed_settings(raw_attributes["settings"])
        attribute_values["settings"] = card_settings
        errors.merge!(setting_errors)
      end

      [attribute_values, errors]
    end

    # Each kind has its own limits (see ContentCard::DEFAULT_SETTINGS); only
    # those keys can be set, and only to whole numbers.
    def parsed_settings(raw_settings)
      if !raw_settings.is_a?(Hash)
        return [nil, { "settings" => ["must be an object"] }]
      end

      allowed_keys = SiteCustomization::ContentCard::DEFAULT_SETTINGS.fetch(@content_card.kind, {}).keys
      card_settings = (@content_card.settings || {}).to_h.stringify_keys
      errors = {}

      raw_settings.each do |key, raw_value|
        if !allowed_keys.include?(key.to_s)
          errors["settings.#{key}"] = ["is not a setting of #{@content_card.kind} cards"]

          next
        end

        result = TypedValueParser.parse(raw_value, SETTING_DEFINITION)

        if result.valid?
          card_settings[key.to_s] = result.value
        else
          errors["settings.#{key}"] = [result.error]
        end
      end

      [card_settings, errors]
    end

    def serialize(content_card)
      allowed_keys = SiteCustomization::ContentCard::DEFAULT_SETTINGS.fetch(content_card.kind, {}).keys

      {
        id: content_card.id,
        kind: content_card.kind,
        landing_page_id: content_card.landing_page_id,
        active: content_card.active,
        position: content_card.given_order,
        settings: (content_card.settings || {}).to_h.stringify_keys.slice(*allowed_keys),
        translations: serialize_translations(content_card, TRANSLATED_ATTRIBUTES),
        updated_at: content_card.updated_at
      }
    end
end

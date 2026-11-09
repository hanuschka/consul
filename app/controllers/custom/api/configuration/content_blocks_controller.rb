class Api::Configuration::ContentBlocksController < Api::Configuration::BaseController
  # The instance-wide blocks of the homepage, the polls pages and the footer.
  # "footer" is the footer's contact block, stored under that name instead of
  # as a custom block.
  CUSTOM_BLOCK_KEYS = %w[
    home_page_1 home_page_1a home_page_2 home_page_4 home_page_5 home_page_6 home_page_7
    home_page_sidebar polls_welcome polls_help footer_block_1 footer_block_2
  ].freeze
  FOOTER_BLOCK_KEY = "footer".freeze
  BLOCK_KEYS = (CUSTOM_BLOCK_KEYS + [FOOTER_BLOCK_KEY]).freeze

  BODY_MAX_LENGTH = 200_000
  MARGIN_BOTTOM_MAX = 500
  VISIBILITY_TIME_ATTRIBUTES = %w[visible_from visible_until].freeze

  ATTRIBUTE_DEFINITIONS = {
    "body" => TypedValueParser::Definition.new(type: :text, allow_blank: true, max_length: BODY_MAX_LENGTH),
    "visible" => TypedValueParser::Definition.new(type: :boolean),
    "margin_bottom" => TypedValueParser::Definition.new(
      type: :integer,
      min: SiteCustomization::ContentBlock::MIN_MARGIN_BOTTOM,
      max: MARGIN_BOTTOM_MAX
    )
  }.freeze

  WRITABLE_ATTRIBUTES = (ATTRIBUTE_DEFINITIONS.keys + VISIBILITY_TIME_ATTRIBUTES).freeze

  before_action :check_block_key, only: [:show, :update]

  def index
    blocks_by_key = global_blocks.index_by { |content_block| block_key(content_block) }

    render json: {
      data: {
        content_blocks: BLOCK_KEYS.map { |key| serialize(key, blocks_by_key[key]) }
      }
    }
  end

  def show
    render json: { data: { content_block: serialize(params[:key], find_or_build_block) } }
  end

  def update
    content_block = find_or_build_block
    attribute_values, errors = parsed_attributes

    if errors.any?
      return render_invalid_values(errors)
    end

    Globalize.with_locale(canonical_locale) { content_block.assign_attributes(attribute_values) }

    if content_block.save
      render json: { data: { content_block: serialize(params[:key], content_block.reload) } }
    else
      render_record_errors(content_block)
    end
  end

  private

    def check_block_key
      if !BLOCK_KEYS.include?(params[:key])
        raise ActiveRecord::RecordNotFound
      end
    end

    def canonical_locale
      SiteCustomization::ContentBlock.canonical_locale
    end

    def global_blocks
      SiteCustomization::ContentBlock
        .includes(:translations)
        .where(projekt_id: nil, newsletter_id: nil, locale: canonical_locale)
        .where(
          "(name = 'custom' AND key IN (:custom_keys)) OR (name = 'footer' AND key IS NULL)",
          custom_keys: CUSTOM_BLOCK_KEYS
        )
    end

    def block_key(content_block)
      content_block.custom? ? content_block.key : FOOTER_BLOCK_KEY
    end

    # Blocks are created on first write, as the inline editor does on first
    # render; reading one that was never written does not create it.
    def find_or_build_block
      if params[:key] == FOOTER_BLOCK_KEY
        block_scope.find_or_initialize_by(name: "footer", key: nil)
      else
        block_scope.find_or_initialize_by(name: "custom", key: params[:key])
      end
    end

    def block_scope
      SiteCustomization::ContentBlock.where(projekt_id: nil, newsletter_id: nil, locale: canonical_locale)
    end

    def parsed_attributes
      raw_attributes = params.require(:content_block).to_unsafe_h
      attribute_values = {}
      errors = (raw_attributes.keys - WRITABLE_ATTRIBUTES).index_with { ["is not a writable attribute"] }

      ATTRIBUTE_DEFINITIONS.each do |name, definition|
        next if !raw_attributes.key?(name)

        result = TypedValueParser.parse(raw_attributes[name], definition)

        if result.valid?
          attribute_values[name] = result.value
        else
          errors[name] = [result.error]
        end
      end

      VISIBILITY_TIME_ATTRIBUTES.each do |name|
        next if !raw_attributes.key?(name)

        visibility_time, error = parsed_time(raw_attributes[name])

        if error
          errors[name] = [error]
        else
          attribute_values[name] = visibility_time
        end
      end

      [attribute_values, errors]
    end

    def parsed_time(raw_value)
      return [nil, nil] if raw_value.blank?

      if !raw_value.is_a?(String)
        return [nil, "must be an ISO 8601 date and time"]
      end

      [Time.zone.iso8601(raw_value), nil]
    rescue ArgumentError
      [nil, "must be an ISO 8601 date and time"]
    end

    def serialize(key, content_block)
      {
        key:,
        body: content_block&.persisted? ? content_block_body(content_block) : nil,
        visible: content_block.nil? || content_block.visible?,
        visible_from: content_block&.visible_from&.iso8601,
        visible_until: content_block&.visible_until&.iso8601,
        margin_bottom: content_block&.margin_bottom || SiteCustomization::ContentBlock::DEFAULT_MARGIN_BOTTOM,
        visibility_status: content_block ? content_block.visibility_status : "visible",
        body_stripped: content_block&.body_stripped? || false,
        updated_at: content_block&.updated_at
      }
    end

    def content_block_body(content_block)
      Globalize.with_locale(canonical_locale) { content_block.body }
    end
end

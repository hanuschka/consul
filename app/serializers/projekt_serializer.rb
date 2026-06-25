class ProjektSerializer < BaseSerializer
  attr_reader :projekt

  def initialize(projekt, options = {})
    @projekt = projekt
    @include_phases = options.fetch(:include_phases, false)
    @include_content_blocks = options.fetch(:include_content_blocks, false)
    @include_text = options.fetch(:include_text, true)
    @include_projekt_settings = options.fetch(:include_projekt_settings, true)
    @include_nested_fields = options.fetch(:include_nested_fields, false)
    @current_api_client = options.fetch(:current_api_client, nil)
  end

  def serialize
    projekt_data =
      projekt.as_json(
        only: [
          :id,
          :name,
          :parent_id,
          :created_at,
          :updated_at,
          :order_number,
          :total_duration_start,
          :total_duration_end,
          :comments_count,
          :geozone_affiliated,
          :level,
          :show_start_date_in_frontend,
          :show_end_date_in_frontend,
          :top_level_projekt_id,
          :tsv,
          :preview_code
        ]
      )

    serialized_image =
      if projekt&.page&.image.present?
        ImageSerializer.new(projekt.page.image, include_variants: true).serialize
      end

    page_data = {
      title: projekt&.page&.title,
      slug: projekt&.page&.slug
    }
    page_data[:image] = serialized_image if serialized_image

    projekt_data.merge!(page: page_data)

    projekt_data.merge!(
      title: projekt&.page&.title,
      subtitle: projekt&.page&.subtitle,
      image: serialized_image
    )

    if @include_text
      concatenated_body = projekt.content_blocks_body

      projekt_data.merge!(
        text: concatenated_body,
        text_html: concatenated_body
      )
    end

    if @include_projekt_settings
      projekt_data.merge!({
        projekt_settings: projekt_settings
      })
    end

    # Include projekt phases if requested
    if @include_phases
      projekt_data.merge!({
        projekt_phases: projekt_phases
      })
    end

    # Include content blocks if requested
    if @include_content_blocks
      projekt_data.merge!({
        content_blocks: content_blocks
      })
    end

    projekt_data
  end

  def projekt_settings
    @projekt.projekt_settings.as_json(only: [:key, :value, :id])
  end

  def projekt_phases
    phases = @projekt.projekt_phases

    if @current_api_client&.public_data?
      phases = phases.select { |phase| phase_visible_to_client?(phase) }
    end

    ProjektPhaseSerializer.serialize_collection(
      phases,
      include_nested_fields: @include_nested_fields,
      current_api_client: @current_api_client
    )
  end

  private

  def phase_visible_to_client?(phase)
    phase.frontend_visibility && phase.active && phase.current?
  end

  def content_blocks
    ContentBlockSerializer.serialize_collection(@projekt.content_blocks.order(:position))
  end

  def self.serialize_collection(projekts, options = {})
    projekts.map { |projekt| new(projekt, options).serialize }
  end
end

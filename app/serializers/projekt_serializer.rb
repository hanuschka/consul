class ProjektSerializer < BaseSerializer
  attr_reader :projekt

  def initialize(projekt, options = {})
    @projekt = projekt
    @include_phases = options.fetch(:include_phases, false)
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

    projekt_data.merge!(
      site_customization_page: {
        title: projekt&.page&.title,
        slug: projekt&.page&.slug
      }
    )

    projekt_data.merge!({
      projekt_settings: projekt_settings
    })

    # Include projekt phases if requested
    if @include_phases
      projekt_data.merge!({
        phases: projekt_phases
      })
    end

    projekt_data
  end

  def projekt_settings
    @projekt.projekt_settings.as_json(only: [:key, :value])
  end

  def projekt_phases
    ProjektPhaseSerializer.serialize_collection(@projekt.projekt_phases)
  end

  def self.serialize_collection(projekts, options = {})
    projekts.map { |projekt| new(projekt, options).serialize }
  end
end

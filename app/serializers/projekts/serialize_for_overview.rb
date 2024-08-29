class Projekts::SerializeForOverview < ApplicationService
  def initialize(projekt)
    @projekt = projekt
  end

  def call
    base = @projekt.as_json(
      only: [:id, :name, :total_duration_start, :total_duration_end],
      include: {
        page: { only: [:title, :subtitle, :slug] },
        map_location: { only: [:latitude, :longitude] }
      }
    )

    if @projekt.map_location.present?
      base.merge!({
        map_location: {
          latitude: @projekt.map_location.latitude,
          longitude: @projekt.map_location.longitude
        }
      })
    end

    if @projekt.current_phases.present?
      base.merge!({
        current_phases: @projekt.current_phases.map do |current_phase|
          {
            id: current_phase.id,
            type: current_phase.type,
            title: current_phase.title,
            fa_icon: ApplicationController.helpers.phase_icon_class(current_phase)
          }
        end
      })
    end

    if @projekt.related_sdgs.present?
      base.merge!({
        sdg_codes: @projekt.sdg_goals.pluck(:code)
      })
    end

    if @projekt.tags.present?
      base.merge!({
        tags: @projekt.tags.pluck(:name)
      })
    end

    if @projekt.image.present?
      base.merge!(
        {
          image_url: Rails.application.routes.url_helpers.polymorphic_url(
            @projekt.image.attachment.variant(
              resize_to_fill: [298, 180],
              saver: { quality: 85 },
              strip: true,
              format: "jpeg"
            ),
            only_path: true
          ),
          popup_image_url: Rails.application.routes.url_helpers.polymorphic_url(
            @projekt.image.attachment.variant(
              resize_to_fill: [221, 170],
              format: "jpeg",
              saver: { strip: true, interlace: "JPEG", quality: 85 }
            ),
            only_path: true
          )
        }
      )
    end

    base
  end
end

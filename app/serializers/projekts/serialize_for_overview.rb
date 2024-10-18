class Projekts::SerializeForOverview < ApplicationService
  def initialize(projekt)
    @projekt = projekt
  end

  def call
    base = @projekt.as_json(
      only: [
        :id,
        :name,
        :total_duration_start,
        :total_duration_end,
        :level,
        :order_number
      ],
      include: {
        page: { only: [:title, :subtitle, :slug] },
        map_location: { only: [:latitude, :longitude] }
      }
    )

    base[:activated] = @projekt.activated?
    base[:custom_page_published] = @projekt.page.status == "published"
    base[:show_in_overview_page] = @projekt.feature?("general.show_in_overview_page")

    if @projekt.map_location.present?
      base.merge!(serialize_map_location)
    end

    if @projekt.projekt_phases.present?
      base.merge!(serialize_phases)
    end

    if @projekt.related_sdgs.present?
      base.merge!({ sdg_codes: @projekt.sdg_goals.pluck(:code) })
    end

    if @projekt.tags.present?
      base.merge!({ tags: @projekt.tags.pluck(:name) })
    end

    if @projekt.image.present?
      base.merge!(serialize_images)
    end

    base
  end

  def serialize_images
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
          resize_to_fill: [251, 185],
          format: "jpeg",
          saver: { strip: true, interlace: "JPEG", quality: 82 }
        ),
        only_path: true
      )
    }
  end

  def serialize_phases
    {
      phases: @projekt.projekt_phases.map do |phase|
        {
          id: phase.id,
          type: phase.type,
          start_date: phase.start_date,
          end_date: phase.end_date,
          active: phase.active,
          regular: ProjektPhase::SPECIAL_PROJEKT_PHASES.exclude?(phase.class.to_s),
          given_order: phase.given_order,
          title: phase.title,
          fa_icon: ApplicationController.helpers.phase_icon_class(phase)
        }
      end
    }
  end

  def serialize_map_location
    {
      map_location: {
        latitude: @projekt.map_location.latitude,
        longitude: @projekt.map_location.longitude
      }
    }
  end

  def get_projekt_filter_categories
    categories = ["all"]

    if projekt_underway?
      categories.push("underway")
    end

    if projekt_ongoing?
      categories.push("ongoing")
    end

    if projekt_upcoming?
      categories.push("upcoming")
    end

    if projekt_expired?
      categories.push("expired")
    end

    categories
  end

  def projekt_current?
    (
      @projekt.total_duration_start.nil? ||
      @projekt.total_duration_start <= time_now
    ) &&
    (
      @projekt.total_duration_end.nil? ||
     @projekt.total_duration_end >= time_now
    )
  end

  def projekt_underway?
    projekt_current? && @projekt.projekt_phases.regular_phases.any?(&:current?)
  end

  def projekt_ongoing?
    projekt_current? && @projekt.projekt_phases.regular_phases.all? { |phase| !phase.current? }
  end

  def projekt_upcoming?
    return false if @projekt.total_duration_start.nil?

    @projekt.total_duration_start > time_now
  end

  def projekt_expired?
    return false if @projekt.total_duration_end.nil?

    @projekt.total_duration_end < time_now
  end

  def time_now
    @time_now ||= Time.zone.today
  end
end

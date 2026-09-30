class MunicipalPlanSerializer < BaseSerializer
  attr_reader :municipal_plan

  def self.serialize_collection(municipal_plans)
    municipal_plans = municipal_plans.to_a
    projekts_by_plan = visible_projekts(municipal_plans.map(&:id)).group_by(&:municipal_plan_id)

    municipal_plans.map do |municipal_plan|
      new(municipal_plan, visible_projekts: projekts_by_plan.fetch(municipal_plan.id, [])).serialize
    end
  end

  def self.visible_projekts(municipal_plan_ids)
    Projekt.visible_for(nil).where(municipal_plan_id: municipal_plan_ids).includes(page: :translations)
  end

  def initialize(municipal_plan, visible_projekts: nil)
    @municipal_plan = municipal_plan
    @visible_projekts = visible_projekts || self.class.visible_projekts(municipal_plan.id)
  end

  def serialize
    plan_data = municipal_plan.as_json(
      only: [
        :id,
        :status,
        :version,
        :content_updated_at,
        :formal_participation,
        :informal_participation,
        :contact_name,
        :contact_phone,
        :contact_email
      ]
    )

    plan_data.merge!(
      title: municipal_plan.title,
      short_description: municipal_plan.short_description,
      further_information: municipal_plan.further_information,
      last_resolution: municipal_plan.last_resolution,
      processing_status: municipal_plan.processing_status,
      next_steps: municipal_plan.next_steps,
      costs: municipal_plan.costs,
      formal_participation_reason: municipal_plan.formal_participation_reason,
      informal_participation_reason: municipal_plan.informal_participation_reason,
      contact_role: municipal_plan.contact_role,
      last_public_change_at: municipal_plan.last_public_change_at
    )

    plan_data[:districts] = municipal_plan.districts.map do |district|
      { id: district.id, name: district.name_for_display }
    end

    plan_data[:topics] = municipal_plan.topics.map do |topic|
      { id: topic.id, name: topic.name }
    end

    plan_data[:links] = municipal_plan.links.map do |link|
      { title: link.title, url: link.url }
    end

    plan_data[:map_location] = serialize_map_location

    plan_data[:projekts] = @visible_projekts.select(&:page).map do |projekt|
      { id: projekt.id, title: projekt.title, slug: projekt.page.slug }
    end

    plan_data
  end

  private

    def serialize_map_location
      map_location = municipal_plan.map_location
      return if map_location.blank?

      pin = map_location.pin_coordinates

      {
        latitude: pin&.dig(:latitude),
        longitude: pin&.dig(:longitude),
        address: map_location.approximated_address
      }
    end
end

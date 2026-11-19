class MunicipalPlanSerializer < BaseSerializer
  attr_reader :municipal_plan

  def self.serialize_collection(municipal_plans, client: nil)
    municipal_plans = municipal_plans.to_a
    projekts_by_plan = visible_projekts(municipal_plans.map(&:id)).group_by(&:municipal_plan_id)
    notices_counts = notices_counts(municipal_plans, client)

    municipal_plans.map do |municipal_plan|
      new(
        municipal_plan,
        visible_projekts: projekts_by_plan.fetch(municipal_plan.id, []),
        notices_count: notices_counts.fetch(municipal_plan.id, 0),
        client: client
      ).serialize
    end
  end

  def self.notices_counts(municipal_plans, client)
    return {} if !client&.admin?

    MunicipalPlan::Notice
      .where(municipal_plan_id: municipal_plans.map(&:id))
      .group(:municipal_plan_id)
      .count
  end

  def self.visible_projekts(municipal_plan_ids)
    Projekt.visible_for(nil).where(municipal_plan_id: municipal_plan_ids).includes(page: :translations)
  end

  def initialize(municipal_plan, visible_projekts: nil, notices_count: nil, client: nil)
    @municipal_plan = municipal_plan
    @visible_projekts = visible_projekts || self.class.visible_projekts(municipal_plan.id)
    @notices_count = notices_count
    @client = client
  end

  def serialize
    plan_data = municipal_plan.as_json(
      only: [
        :id,
        :status,
        :version,
        :content_updated_at,
        :given_order,
        :city_wide,
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
      translations: serialize_translations(municipal_plan),
      last_public_change_at: municipal_plan.last_public_change_at
    )

    plan_data[:procedure_step] = serialize_procedure_step

    plan_data[:districts] = municipal_plan.districts.map do |district|
      { id: district.id, name: district.name_for_display }
    end

    plan_data[:topics] = municipal_plan.topics.map do |topic|
      { id: topic.id, name: topic.name }
    end

    plan_data[:links] = municipal_plan.links.map do |link|
      { title: link.title, url: link.url }
    end

    plan_data[:map_location] = serialize_displayed_map_location

    plan_data[:projekts] = @visible_projekts.select(&:page).map do |projekt|
      { id: projekt.id, title: projekt.title, slug: projekt.page.slug }
    end

    if admin_client?
      plan_data.merge!(
        archive_on: municipal_plan.archive_on,
        released_at: municipal_plan.released_at,
        responsible: serialize_responsible,
        notices_count: @notices_count || municipal_plan.notices.count,
        pending_working_copy: municipal_plan.working_copy.present?
      )
    end

    plan_data
  end

  private

    def serialize_procedure_step
      step = municipal_plan.procedure_step
      return if step.blank?

      { id: step.id, name: step.name }
    end

    def serialize_displayed_map_location
      map_location = municipal_plan.displayed_map_location
      return if map_location.blank?

      pin = map_location.pin_coordinates
      map_location_data = serialize_map_location(map_location)

      if pin.present? && pin.values.all?(Numeric)
        map_location_data.merge!(latitude: pin[:latitude], longitude: pin[:longitude])
      end

      map_location_data.merge(address: map_location.approximated_address)
    end

    def serialize_responsible
      responsible = municipal_plan.responsible
      return if responsible.blank?

      { id: responsible.id, type: municipal_plan.responsible_type, name: responsible.name }
    end
end

class Api::MunicipalPlansController < Api::BaseController
  include MapLocationAttributes

  ASSIGNABLE_RESPONSIBLE_TYPES = {
    "MunicipalPlan::Officer" => MunicipalPlan::Officer,
    "MunicipalPlan::OfficerGroup" => MunicipalPlan::OfficerGroup
  }.freeze

  CONTENT_ATTRIBUTES = %i[
    city_wide procedure_step_id formal_participation informal_participation
    contact_name contact_phone contact_email
  ].freeze

  CONTENT_COLLECTION_KEYS = %w[
    district_ids topic_ids map_location_attributes translations links responsible_type responsible_id
  ].freeze

  before_action :check_read_access!, only: [:index, :show]
  before_action :check_admin_access!, only: [:create, :update, :order]
  before_action :check_module_enabled!
  around_action :audit_changes_as_client, only: [:create, :update, :order]

  rescue_from MunicipalPlansApiQuery::InvalidParameter, with: :render_invalid_parameter

  def index
    municipal_plans = MunicipalPlansApiQuery.call(params)
                                            .page(params[:page])
                                            .per(per_page)

    if admin_client?
      municipal_plans = municipal_plans.includes(:working_copy, :responsible)
    end

    render json: {
      data: {
        municipal_plans: MunicipalPlanSerializer.serialize_collection(municipal_plans, client: current_client)
      },
      pagination: pagination_meta(municipal_plans)
    }
  end

  def show
    municipal_plan = visible_plans.find(params[:id])

    render_municipal_plan(municipal_plan)
  end

  def create
    municipal_plan = MunicipalPlan.new(municipal_plan_params)
    translations = assign_requested_translations(municipal_plan, :municipal_plan, translated_attribute_names)
    assign_links(municipal_plan)

    if !assign_responsible(municipal_plan)
      return render_unassignable_responsible
    end

    released_plan = MunicipalPlan.transaction do
      save_or_raise(municipal_plan, translations)
      release!(municipal_plan)
    end

    render_municipal_plan(released_plan, status: :created)
  end

  def update
    municipal_plan = MunicipalPlan.released_versions.find(params[:id])

    if content_change_requested? && municipal_plan.working_copy.present?
      return render_invalid_values(
        "base" => ["has a pending change in /adm; release or discard it there first"]
      )
    end

    MunicipalPlan.transaction do
      if content_change_requested?
        municipal_plan = write_content(municipal_plan)
      end

      if archive_on_requested?
        municipal_plan.update!(archive_on: params[:municipal_plan][:archive_on].presence)
      end
    end

    render_municipal_plan(municipal_plan.reload)
  end

  def order
    orderable_ids = MunicipalPlan.released_versions.where.not(status: "archived").ids
    ordered_ids = Array.wrap(params[:ids]).map { it.to_s }.grep(/\A\d+\z/).map(&:to_i) & orderable_ids

    MunicipalPlan.apply_editorial_order(ordered_ids)

    render json: { data: { ordered_ids: ordered_ids } }
  end

  private

    def visible_plans
      if admin_client?
        MunicipalPlan.released_versions
      else
        MunicipalPlan.released_versions.published
      end
    end

    def render_municipal_plan(municipal_plan, status: :ok)
      render json: {
        data: { municipal_plan: MunicipalPlanSerializer.new(municipal_plan, client: current_client).serialize }
      }, status: status
    end

    def write_content(municipal_plan)
      if municipal_plan.draft?
        write_draft(municipal_plan)
      else
        working_copy = MunicipalPlans::WorkingCopyService.call(municipal_plan)
        translations = assign_content(working_copy)
        save_or_raise(working_copy, translations)

        release!(working_copy)
      end
    end

    def write_draft(municipal_plan)
      associations_before = association_fingerprint(municipal_plan)
      translations = assign_content(municipal_plan)
      save_or_raise(municipal_plan, translations)

      if !municipal_plan.saved_change_to_version? &&
          association_fingerprint(municipal_plan.reload) != associations_before
        municipal_plan.register_content_change!
      end

      municipal_plan
    end

    def assign_content(municipal_plan)
      content_params = municipal_plan_params
      map_location_params = content_params[:map_location_attributes]

      if map_location_params.present?
        content_params = with_existing_map_location_id(
          municipal_plan,
          content_params.merge(map_location_attributes: map_location_params.except(:id))
        )
      end

      municipal_plan.assign_attributes(content_params)
      assign_links(municipal_plan)

      if !assign_responsible(municipal_plan)
        raise ActiveRecord::RecordInvalid, responsible_error(municipal_plan)
      end

      assign_requested_translations(municipal_plan, :municipal_plan, translated_attribute_names)
    end

    def save_or_raise(municipal_plan, translations)
      if !save_with_translations(municipal_plan, translations)
        raise ActiveRecord::RecordInvalid, municipal_plan
      end
    end

    def release!(municipal_plan)
      municipal_plan.submitted_at ||= Time.current

      if !municipal_plan.valid?
        raise ActiveRecord::RecordInvalid, municipal_plan
      end

      MunicipalPlans::ReleaseService.call(municipal_plan)
    end

    def assign_links(municipal_plan)
      return if !params[:municipal_plan].key?(:links)

      municipal_plan.links.each(&:mark_for_destruction)

      Array.wrap(params[:municipal_plan][:links]).each_with_index do |link, index|
        if !link.is_a?(ActionController::Parameters)
          raise ActionController::ParameterMissing, :links
        end

        municipal_plan.links.build(title: link[:title], url: link[:url], given_order: index + 1)
      end
    end

    def assign_responsible(municipal_plan)
      return true if !params[:municipal_plan].key?(:responsible_type)

      responsible_class = ASSIGNABLE_RESPONSIBLE_TYPES[params[:municipal_plan][:responsible_type].to_s]
      responsible = responsible_class&.find_by(id: params[:municipal_plan][:responsible_id])
      return false if responsible.blank?

      municipal_plan.responsible = responsible
      true
    end

    def responsible_error(municipal_plan)
      municipal_plan.errors.add(:responsible, "must be an existing #{ASSIGNABLE_RESPONSIBLE_TYPES.keys.join(" or ")}")
      municipal_plan
    end

    def render_unassignable_responsible
      render_invalid_values(
        "responsible" => ["must be an existing #{ASSIGNABLE_RESPONSIBLE_TYPES.keys.join(" or ")}"]
      )
    end

    def association_fingerprint(municipal_plan)
      [
        municipal_plan.district_ids.sort,
        municipal_plan.topic_ids.sort,
        municipal_plan.links.map { |link| [link.id, link.title, link.url, link.given_order] }.sort_by(&:first)
      ]
    end

    def content_change_requested?
      (params.require(:municipal_plan).keys & content_keys).any?
    end

    def content_keys
      CONTENT_ATTRIBUTES.map(&:to_s) + translated_attribute_names + CONTENT_COLLECTION_KEYS
    end

    def archive_on_requested?
      params.require(:municipal_plan).key?(:archive_on)
    end

    def translated_attribute_names
      MunicipalPlan.translated_attribute_names.map(&:to_s)
    end

    def municipal_plan_params
      params.require(:municipal_plan).permit(
        *CONTENT_ATTRIBUTES,
        *translated_attribute_names,
        district_ids: [],
        topic_ids: [],
        map_location_attributes: map_location_attributes_api
      ).to_h
    end

    def per_page
      requested = params[:per_page].to_i
      requested.positive? ? [requested, DEFAULT_PER_PAGE].min : DEFAULT_PER_PAGE
    end

    def check_module_enabled!
      raise ActiveRecord::RecordNotFound if Setting["process.municipal_plans"].blank?
    end

    def render_invalid_parameter(exception)
      render_bad_request(exception.message)
    end

    def pagination_meta(collection)
      {
        current_page: collection.current_page,
        total_pages: collection.total_pages,
        total_count: collection.total_count,
        per_page: collection.limit_value
      }
    end
end

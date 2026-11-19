class Api::MilestonesController < Api::BaseController
  include Translatable
  include ImageAttributes
  include DocumentAttributes

  PRELOADS = [
    :translations,
    :status,
    { image: { attachment_attachment: :blob } },
    { documents: { attachment_attachment: :blob } }
  ].freeze

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_milestone, only: [:show, :update, :destroy]

  def index
    check_read_access!
    check_phase_visible!(@projekt_phase)

    milestones = paginate(
      @projekt_phase.milestones
        .includes(*PRELOADS, milestoneable: { projekt: { page: :translations } })
        .order_by_publication_date
    )

    serialized_milestones = MilestoneSerializer.serialize_collection(milestones, client: current_client)

    render json: {
      data: { milestones: serialized_milestones },
      pagination: pagination_meta(milestones)
    }
  end

  def show
    check_read_access!

    if milestone_hidden_from_client?(@milestone)
      raise ForbiddenError, "Access denied"
    end

    render json: { data: { milestone: MilestoneSerializer.new(@milestone, client: current_client).serialize } }
  end

  def create
    check_admin_access!
    milestone = @projekt_phase.milestones.new(milestone_params)
    translations = assign_requested_translations(milestone, :milestone, MilestoneSerializer::TRANSLATED_ATTRIBUTES)
    assign_document_authors(milestone)

    if save_with_translations(milestone, translations)
      process_image_with_base64(milestone, params[:milestone][:image_attributes])
      serialized_milestone = MilestoneSerializer.new(milestone.reload, client: current_client).serialize

      render json: { data: { milestone: serialized_milestone } }, status: 201
    else
      render_translated_record_errors(milestone)
    end
  end

  def update
    check_admin_access!
    @milestone.assign_attributes(milestone_params)
    translations = assign_requested_translations(@milestone, :milestone, MilestoneSerializer::TRANSLATED_ATTRIBUTES)
    assign_document_authors(@milestone)

    if save_with_translations(@milestone, translations)
      if params[:milestone].key?(:image_attributes)
        process_image_with_base64(@milestone, params[:milestone][:image_attributes])
      end

      serialized_milestone = MilestoneSerializer.new(@milestone.reload, client: current_client).serialize

      render json: { data: { milestone: serialized_milestone } }
    else
      render_translated_record_errors(@milestone)
    end
  end

  def destroy
    check_admin_access!

    if @milestone.destroy
      render json: { message: "Milestone destroyed" }
    else
      render_record_errors(@milestone)
    end
  end

  private

  def milestone_params
    with_decoded_documents(
      params.require(:milestone).permit(
        :title,
        :description,
        :custom_date,
        :publication_date,
        :status_id,
        translation_params(Milestone, only: [:title, :description, :custom_date]),
        documents_attributes: document_attributes_api
      )
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::MilestonePhase.find(params[:projekt_phase_id])
  end

  def find_milestone
    @milestone = Milestone.includes(*PRELOADS).find(params[:id])
  end

  def milestone_hidden_from_client?(milestone)
    return false if !current_client.public_data?

    milestoneable = milestone.milestoneable

    case milestoneable
    when ProjektPhase
      !publicly_visible_phase?(milestoneable)
    when DeficiencyReport
      !milestoneable.publicly_visible?
    when Proposal
      !milestoneable.published? || !milestoneable.admin_accepted? ||
        !publicly_visible_phase?(milestoneable.projekt_phase)
    when Budget::Investment
      milestoneable.budget&.projekt_phase.blank? ||
        !publicly_visible_phase?(milestoneable.budget.projekt_phase)
    else
      true
    end
  end
end

class Api::TextsController < Api::BaseController
  before_action :find_projekt_phase, only: [:index]

  def index
    check_read_access!

    if current_client.public_data? && !publicly_visible_phase?
      raise ForbiddenError, "Access denied"
    end

    legislation_process = @projekt_phase.legislation_process

    if legislation_process.blank?
      return render json: { data: { texts: [] }, pagination: empty_pagination_meta }
    end

    texts = paginate(readable_draft_versions(legislation_process))

    render json: {
      data: { texts: LegislationDraftVersionSerializer.serialize_collection(texts) },
      pagination: pagination_meta(texts)
    }
  end

  private

  def find_projekt_phase
    @projekt_phase = ProjektPhase::LegislationPhase.find(params[:projekt_phase_id])
  end

  def publicly_visible_phase?
    @projekt_phase.frontend_visibility && @projekt_phase.active?
  end

  def readable_draft_versions(legislation_process)
    draft_versions = legislation_process.draft_versions.includes(:translations)

    if current_client.public_data?
      draft_versions.where(status: "published")
    else
      draft_versions
    end
  end
end

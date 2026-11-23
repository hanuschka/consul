class Api::PollsController < Api::BaseController
  include Translatable
  include ImageAttributes

  TRANSLATED_ATTRIBUTES = PollSerializer::TRANSLATED_ATTRIBUTES

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_poll, only: [:show, :update, :destroy, :go_live, :results]

  def index
    check_read_access!

    if @projekt_phase.present?
      if phase_hidden_from_client?(@projekt_phase)
        raise ForbiddenError, "Access denied"
      end

      polls = @projekt_phase.polls.preload(PollSerializer::PRELOADS)
    else
      polls = Poll.preload(PollSerializer::PRELOADS)

      if current_client.public_data?
        polls = restrict_to_public_phases(polls)
      end
    end

    polls = paginate(polls.order(created_at: :asc))

    serialized_polls = PollSerializer.serialize_collection(polls, client: current_client)

    render json: {
      data: { polls: serialized_polls },
      pagination: pagination_meta(polls)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase if @projekt_phase.blank?
    poll = @projekt_phase.polls.new(poll_params)
    translations = assign_requested_translations(poll, :poll, TRANSLATED_ATTRIBUTES)

    if save_with_translations(poll, translations)
      process_image_with_base64(poll, params[:poll][:image_attributes])

      render json: { data: { poll: serialize_poll(poll) } }, status: 201
    else
      render json: { error: { messages: TranslatedRecordErrors.full_messages(poll) } }, status: 422
    end
  end

  def show
    check_read_access!
    check_phase_visible!(@poll.projekt_phase)

    render json: { data: { poll: serialize_poll(@poll) } }
  end

  def update
    check_admin_access!
    @poll.assign_attributes(poll_params)
    translations = assign_requested_translations(@poll, :poll, TRANSLATED_ATTRIBUTES)

    if save_with_translations(@poll, translations)
      process_image_with_base64(@poll, params[:poll][:image_attributes])

      render json: { data: { poll: serialize_poll(@poll) } }
    else
      render json: { error: { messages: TranslatedRecordErrors.full_messages(@poll) } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @poll.destroy
      render json: { message: "Poll destroyed" }
    else
      render json: { error: { messages: @poll.errors.messages } }, status: 422
    end
  end

  # Same transition as the /adm "go live" button: every answer, voter and
  # booth result collected in test mode is deleted. A live poll is refused,
  # since its votes are real.
  def go_live
    check_admin_access!

    if @poll.live?
      return render_invalid_values({ "live" => ["poll is already live"] })
    end

    @poll.go_live!

    render json: { data: { poll: serialize_poll(@poll.reload) } }
  end

  def results
    check_read_access!
    check_phase_visible!(@poll.projekt_phase)

    if !PollSerializer.results_visible?(@poll, current_client)
      raise ForbiddenError, "The results of this poll are not public."
    end

    render json: { data: { results: Polls::ResultsSummary.call(@poll) } }
  end

  private

  def poll_params
    params.require(:poll).permit(
      :name,
      :summary,
      :description,
      :closing_note,
      :starts_at,
      :ends_at,
      :geozone_restricted,
      :published,
      :show_summary_instead_of_questions,
      :budget_id,
      geozone_ids: [],
    )
  end

  def serialize_poll(poll)
    PollSerializer.new(poll, client: current_client).serialize
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::VotingPhase.find(params[:projekt_phase_id])
  end

  def find_poll
    @poll = Poll.includes(PollSerializer::PRELOADS).find(params[:id])
  end
end

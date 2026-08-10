class Api::PollsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_poll, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      if current_client.public_data?
        unless @projekt_phase.frontend_visibility && @projekt_phase.active?
          return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
        end
      end

      polls = @projekt_phase.polls
        .includes(:projekt_phase, projekt_phase: :projekt)
    else
      polls = Poll.includes(:projekt_phase, projekt_phase: :projekt)

      if current_client.public_data?
        polls = polls.joins(:projekt_phase)
          .where(projekt_phases: { frontend_visibility: true, active: true })
          .distinct
      end
    end

    polls = paginate(polls.order(created_at: :asc))

    serialized_polls = PollSerializer.serialize_collection(polls)

    render json: {
      data: { polls: serialized_polls },
      pagination: pagination_meta(polls)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?
    poll = @projekt_phase.polls.new(poll_params)

    if poll.save
      serialized_poll = PollSerializer.new(poll).serialize

      render json: { data: { poll: serialized_poll } }, status: 201
    else
      render json: { error: { messages: poll.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_poll = PollSerializer.new(@poll).serialize

    render json: { data: { poll: serialized_poll } }
  end

  def update
    check_admin_access!
    if @poll.update(poll_params)
      serialized_poll = PollSerializer.new(@poll).serialize

      render json: { data: { poll: serialized_poll } }
    else
      render json: { error: { messages: @poll.errors.full_messages } }, status: 422
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
      :budget_id,
      geozone_ids: [],
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::VotingPhase.find(params[:projekt_phase_id])
  end

  def find_poll
    @poll = Poll.includes(:projekt_phase, projekt_phase: :projekt).find(params[:id])
  end
end


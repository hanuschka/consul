class Api::PollsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:create]
  before_action :find_poll, only: [:show, :update, :destroy]

  def create
    poll = @projekt_phase.polls.new(poll_params)

    if poll.save
      serialized_poll = PollSerializer.new(poll).serialize

      render json: { data: { poll: serialized_poll } }, status: 201
    else
      render json: { error: { messages: poll.errors.full_messages } }, status: 422
    end
  end

  def update
    if @poll.update(poll_params)
      serialized_poll = PollSerializer.new(@poll).serialize

      render json: { data: { poll: serialized_poll } }
    else
      render json: { error: { messages: @poll.errors.full_messages } }, status: 422
    end
  end

  def destroy
    if @poll.destroy
      render json: { message: "Poll destroyed" }
    else
      render json: { error: { messages: @poll.errors.messages } }, status: 422
    end
  end

  private

  def poll_params
    params.require(:poll).permit(
      :starts_at,
      :ends_at,
      :geozone_restricted,
      :summary,
      :description,
      :budget_id,
      *translation_params(Poll),
      geozone_ids: [],
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::VotingPhase.find(params[:projekt_phase_id])
  end

  def find_poll
    @poll = Poll.find(params[:id])
  end
end


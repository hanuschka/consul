class Adm::Projekts::StatQuestionsController < Adm::Projekts::BaseController
  before_action :find_projekt_phase
  before_action :find_stat_question

  def poll
    authorize @projekt_phase, :update?, policy_class: Adm::Projekts::ProjektPhasePolicy

    respond_to do |format|
      format.turbo_stream
    end
  end

  private

    def find_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
      @projekt = @projekt_phase.projekt
    end

    def find_stat_question
      @stat_question = @projekt_phase.stat_questions.find(params[:id])
    end
end

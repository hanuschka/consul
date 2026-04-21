class Adm::Ideas::IdeaAuditsController < Adm::Ideas::BaseController
  def show
    @idea = Idea.find(params[:idea_id])
    authorize @idea, :show?, policy_class: Adm::Ideas::IdeaPolicy

    @audit = @idea.own_and_associated_audits.find(params[:id])
  end
end

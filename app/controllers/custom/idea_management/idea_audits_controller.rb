class IdeaManagement::IdeaAuditsController < IdeaManagement::BaseController
  def show
    idea = Idea.find(params[:idea_id])
    @audit = idea.own_and_associated_audits.find(params[:id])

    render "admin/audits/show"
  end
end

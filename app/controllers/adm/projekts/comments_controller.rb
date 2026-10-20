class Adm::Projekts::CommentsController < Adm::Projekts::BaseController
  include Adm::HidesContributions

  before_action :find_projekt_phase
  before_action :find_comment

  def hide
    authorize [:adm, @comment], :hide?

    hide_and_notify_author(@comment)
    @comment.reload
  end

  def unhide
    authorize [:adm, @comment], :unhide?

    @comment.restore
    Activity.log(current_user, :restore, @comment)
    @comment.reload
  end

  def ignore_flag
    authorize [:adm, @comment], :ignore_flag?

    @comment.ignore_flag
    @comment.reload
  end

  private

    def find_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def find_comment
      @comment = Comment.with_hidden.find(params[:id])
    end
end

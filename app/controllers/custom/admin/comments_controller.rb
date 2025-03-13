class Admin::CommentsController < Admin::BaseController
  def index
    @comments = Comment.sort_by_newest.page(params[:page])

    respond_to do |format|
      format.html
      format.csv do
        CsvJobs::CommentsJob.perform_later(current_user.id, Comment.not_valuations.ids, "all")
        redirect_to admin_comments_path, notice: "Export wird vorbereitet. Du erhältst eine E-Mail, sobald der Export fertig ist."
      end
    end
  end
end

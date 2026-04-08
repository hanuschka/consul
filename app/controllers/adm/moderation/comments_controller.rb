class Adm::Moderation::CommentsController < Adm::Moderation::BaseController
  FILTERS = %w[pending_flag_review with_ignored_flag hidden all].freeze

  def index
    authorize Comment, policy_class: Adm::Moderation::CommentPolicy
    base_scope = policy_scope(Comment, policy_scope_class: Adm::Moderation::CommentPolicy::Scope)
    @current_filter = FILTERS.include?(params[:filter]) ? params[:filter] : FILTERS.first
    base_scope = apply_filter(base_scope)
    @pagy, @comments = pagy(CommentsQuery.call(base_scope, params))

    @body_header_options = { search: true }
    @flags_count_header_options = { sort: true }

    @breadcrumbs = [
      { name: I18n.t("adm.moderation.menu.title"), icon: "comment" },
      { name: I18n.t("adm.moderation.menu.comments") }
    ]
  end

  def hide
    @comment = Comment.find(params[:id])
    authorize @comment, :hide?, policy_class: Adm::Moderation::CommentPolicy

    @comment.hide
    Activity.log(current_user, :hide, @comment)
    @comment.reload
  end

  def unhide
    @comment = Comment.with_hidden.find(params[:id])
    authorize @comment, :unhide?, policy_class: Adm::Moderation::CommentPolicy

    @comment.restore
    Activity.log(current_user, :restore, @comment)
    @comment.reload
  end

  def ignore_flag
    @comment = Comment.find(params[:id])
    authorize @comment, :ignore_flag?, policy_class: Adm::Moderation::CommentPolicy

    @comment.ignore_flag
    @comment.reload
  end

  private

    def apply_filter(scope)
      case @current_filter
      when "pending_flag_review"
        scope.pending_flag_review
      when "with_ignored_flag"
        scope.with_ignored_flag
      when "hidden"
        scope.only_hidden
      else
        scope
      end
    end
end

class Api::CommentsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index, :create]
  before_action :find_comment, only: [:show]

  def index
    check_read_access!
    comments = @projekt_phase.comments
      .includes(:user)
      .order(created_at: :desc)
      .page(params[:page])
      .per(params[:per_page] || 100)

    serialized_comments = CommentSerializer.serialize_collection(comments)

    render json: {
      data: { comments: serialized_comments },
      pagination: pagination_meta(comments)
    }
  end

  def show
    check_read_access!
    serialized_comment = CommentSerializer.new(@comment).serialize

    render json: { data: { comment: serialized_comment } }
  end

  def create
    check_admin_access!
    comment = @projekt_phase.comments.new(comment_params)
    comment.user = @current_client.user

    if comment.save
      serialized_comment = CommentSerializer.new(comment).serialize

      render json: { data: { comment: serialized_comment } }, status: 201
    else
      render json: { error: { messages: comment.errors.full_messages } }, status: 422
    end
  end

  private

  def comment_params
    params.require(:comment).permit(
      :user_id,
      :parent_id,
      :ancestry,
      **translation_params(Comment)
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::CommentPhase.find(params[:projekt_phase_id])
  end

  def find_comment
    @comment = Comment.find(params[:id])
  end

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end

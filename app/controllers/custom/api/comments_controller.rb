class Api::CommentsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_comment, only: [:show, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      if current_client.public_data?
        unless @projekt_phase.frontend_visibility && @projekt_phase.active?
          return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
        end
      end

      comments = @projekt_phase.comments
        .includes(:user, :commentable)
    else
      comments = Comment.includes(:user, :commentable)

      if current_client.public_data?
        comments = comments.joins(commentable: :projekt_phases)
          .where(projekt_phases: { frontend_visibility: true, active: true })
          .distinct
      end
    end

    valid_orders = %w[most_voted newest oldest]
    current_order = valid_orders.include?(params[:sort]) ? params[:sort] : "oldest"

    comments = case current_order
               when "newest"
                 comments.order(created_at: :desc)
               when "most_voted"
                 comments.order(cached_votes_total: :desc, created_at: :asc)
               else
                 comments.order(created_at: :asc)
               end

    comments = paginate(comments, default_per_page: COMMENTS_PER_PAGE)

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
    find_projekt_phase unless @projekt_phase.present?
    comment = @projekt_phase.comments.new(comment_params)
    comment.user = @current_client.content_author

    if comment.save
      serialized_comment = CommentSerializer.new(comment).serialize

      render json: { data: { comment: serialized_comment } }, status: 201
    else
      render json: { error: { messages: comment.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!
    if @comment.destroy
      render json: { message: "Comment destroyed" }
    else
      render json: { error: { messages: @comment.errors.messages } }, status: 422
    end
  end

  private

  def comment_params
    params.require(:comment).permit(
      :body,
      :user_id,
      :parent_id,
      :ancestry
    )
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::CommentPhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?
  end

  def find_comment
    @comment = Comment.includes(:user, :commentable).find(params[:id])
  end
end

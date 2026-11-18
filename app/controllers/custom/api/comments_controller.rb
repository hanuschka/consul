class Api::CommentsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index], if: -> { params[:projekt_phase_id].present? }
  before_action :find_commentable, only: [:create]
  before_action :find_comment, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      if phase_hidden_from_client?(@projekt_phase)
        raise ForbiddenError, "Access denied"
      end

      comments = @projekt_phase.comments
        .includes(:commentable, user: :organization)
    else
      comments = Comment.includes(:commentable, user: :organization)

      if current_client.public_data?
        comments = comments.on_public_projekt_phases
      end
    end

    if !admin_client?
      comments = comments.not_valuations
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

    serialized_comments = CommentSerializer.serialize_collection(comments, client: current_client)

    render json: {
      data: { comments: serialized_comments },
      pagination: pagination_meta(comments)
    }
  end

  def show
    check_read_access!

    if !admin_client? && !publicly_visible_comment?(@comment)
      return render_not_found
    end

    serialized_comment = CommentSerializer.new(@comment, client: current_client).serialize

    render json: { data: { comment: serialized_comment } }
  end

  def create
    check_admin_access!
    comment = @commentable.comments.new(comment_params)
    comment.user = @current_client.content_author

    if comment.parent.present? && comment.parent.commentable != @commentable
      render json: {
        error: { messages: ["Parent comment belongs to a different resource."] }
      }, status: 422
    elsif comment.save
      serialized_comment = CommentSerializer.new(comment, client: current_client).serialize

      render json: { data: { comment: serialized_comment } }, status: 201
    else
      render json: { error: { messages: comment.errors.full_messages } }, status: 422
    end
  end

  def update
    check_admin_access!

    if @comment.update(comment_update_params)
      serialized_comment = CommentSerializer.new(@comment, client: current_client).serialize

      render json: { data: { comment: serialized_comment } }
    else
      render json: { error: { messages: @comment.errors.full_messages } }, status: 422
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
      :parent_id,
      :ancestry
    )
  end

  def comment_update_params
    params.require(:comment).permit(:body)
  end

  def find_projekt_phase
    @projekt_phase = ProjektPhase::CommentPhase.find(params[:projekt_phase_id]) if params[:projekt_phase_id].present?
  end

  def find_commentable
    @commentable =
      if params[:proposal_id].present?
        Proposal.find(params[:proposal_id])
      elsif params[:budget_investment_id].present?
        Budget::Investment.find(params[:budget_investment_id])
      else
        ProjektPhase::CommentPhase.find(params[:projekt_phase_id])
      end
  end

  def publicly_visible_comment?(comment)
    Comment.on_public_projekt_phases.not_valuations.exists?(comment.id)
  end

  def find_comment
    @comment = Comment.includes(:user, :commentable).find(params[:id])
  end
end

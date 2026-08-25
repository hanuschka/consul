class IdeasController < ApplicationController
  include FeatureFlags
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes
  include OnBehalfOfAccountLinking
  # include Search

  feature_flag :ideas

  before_action :authenticate_user!, except: [:index, :show, :json_data]
  before_action :set_idea, only: [:show, :vote, :unvote, :json_data]

  skip_authorization_check only: [:json_data]

  has_orders ->(c) { Idea.idea_orders }, only: :index
  has_orders %w[newest most_voted oldest], only: :show

  def index
    authorize! :index, Idea

    @ideas = Idea.accepted

    filter_by_category
    filter_by_status
    filter_by_quorum

    @ideas_coordinates = all_idea_map_locations(@ideas)

    @ideas = @ideas.send("sort_by_#{@current_order}")
                   .page(params[:page])
  end

  def show
    @idea = Idea.find(params[:id])
    authorize! :show, @idea

    @comment_tree = CommentTree.new(@idea, params[:page], @current_order)
  end

  def new
    @idea = Idea.new
    authorize! :create, @idea
  end

  def create
    @idea = Idea.new(idea_params.merge(author: current_user))
    authorize! :create, @idea

    @idea.officer = @idea.district&.default_idea_officer || @idea.category&.default_idea_officer

    if @idea.valid? && link_on_behalf_of_account(@idea) && @idea.save
      if @idea.officer.present?
        IdeaMailer.notify_officer(@idea, @idea.officer).deliver_later
        Notification.add(@idea.officer.user, @idea)
        Activity.log(@idea.officer.user, "email", @idea)
      end

      redirect_to idea_path(@idea)
    else
      render :new
    end
  end

  def suggest
    @limit = 5
    @resources = @search_terms.present? ? Idea.accepted.search(@search_terms) : nil
  end

  def vote
    authorize! :vote, @idea

    @follow = Follow.find_or_create_by!(user: current_user, followable: @idea)
    @voted = @idea.vote_by(voter: current_user, vote: "yes")
  end

  def unvote
    authorize! :unvote, @idea

    @follow = Follow.find_by(user: current_user, followable: @idea)
    @follow&.destroy!
    @voted = !@idea.unvote_by(current_user)
  end

  def json_data
    image_url = url_for @idea.image.attachment.variant(
                  resize_to_fill: MapLocation::MAP_POPUP_STANDARD_IMAGE_SIZE,
                  format: "jpeg",
                  saver: { strip: true, interlace: "JPEG", quality: 80 }
    ) if @idea.image&.attachment&.attached?


    data = {
      resource_type: "idea",
      id: @idea.id,
      image_url: image_url,
      image_ai_label_html: helpers.ai_image_label_html(@idea.image),
      title: @idea.title
    }.to_json

    respond_to do |format|
      format.json { render json: data }
    end
  end

  private

    def idea_params
      attributes = [:resource_terms,
                    :idea_category_id,
                    :video_url, :on_behalf_of,
                    :on_behalf_of_company_name, :on_behalf_of_email,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:idea).permit(attributes, translation_params(Idea))
    end

    def all_idea_map_locations(ideas_for_map)
      ids = ideas_for_map.except(:limit, :offset, :order).ids.uniq

      MapLocation
        .with_idea_associations
        .where(mappable_id: ids)
        .map(&:features_json_data)
    end

    def set_idea
      @idea = Idea.find(params[:id])
    end

    def filter_by_category
      return unless params[:idea_category].present?

      @ideas = @ideas.where(idea_category_id: params[:idea_category])
    end

    def filter_by_status
      return unless params[:status].in? %w[active archived]

      @ideas = @ideas.send("filter_by_status_#{params[:status]}")
    end

    def filter_by_quorum
      return unless params[:quorum].in? %w[reached not_reached]

      @ideas = @ideas.send("filter_by_quorum_#{params[:quorum]}")
    end
end

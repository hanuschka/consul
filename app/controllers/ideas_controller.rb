class IdeasController < ApplicationController
  include FeatureFlags
  include Translatable
  include MapLocationAttributes
  include ImageAttributes
  include DocumentAttributes
  # include Search

  feature_flag :ideas

  before_action :authenticate_user!, except: [:index, :show]
  before_action :set_idea, only: [:show, :vote, :unvote]
  skip_authorization_check only: [:index, :show]

  has_orders ->(c) { Idea.idea_orders }, only: :index
  has_orders %w[newest most_voted oldest], only: :show

  def index
    @ideas = Idea.all
    @ideas_coordinates = all_idea_map_locations(@ideas)

    @ideas = @ideas.send("sort_by_#{@current_order}")
                   .page(params[:page])
  end

  def show
    @idea = Idea.find(params[:id])
    @comment_tree = CommentTree.new(@idea, params[:page], @current_order)
  end

  def new
    @idea = Idea.new
    authorize! :create, @idea
  end

  def create
    @idea = Idea.new(idea_params.merge(author: current_user))
    authorize! :create, @idea

    if @idea.save
      redirect_to idea_path(@idea)
    else
      render :new
    end
  end

  def suggest
    @limit = 5
    @resources = @search_terms.present? ? Idea.admin_accepted.search(@search_terms) : nil
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
    idea = Idea.find(params[:id])

    image_url = idea.image.present? ? url_for(idea.image.attachment.variant(resize_to_fill: [221, 170], format: "jpeg", saver: { strip: true, interlace: "JPEG", quality: 80 })) : nil

    data = {
      idea_id: idea.id,
      image_url: image_url,
      idea_title: idea.title
    }.to_json

    respond_to do |format|
      format.json { render json: data }
    end
  end

  private

    def idea_params
      attributes = [:resource_terms,
                    :video_url, :on_behalf_of,
                    map_location_attributes: map_location_attributes,
                    documents_attributes: document_attributes,
                    image_attributes: image_attributes]
      params.require(:idea).permit(attributes, translation_params(Idea))
    end

    def all_idea_map_locations(ideas_for_map)
      ids = ideas_for_map.except(:limit, :offset, :order).ids.uniq

      MapLocation.where(idea_id: ids).map do |map_location|
        map_location.shape_json_data.presence || map_location.json_data
      end
    end

    def set_idea
      @idea = Idea.find(params[:id])
    end
end

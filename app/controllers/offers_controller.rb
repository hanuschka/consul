class OffersController < ApplicationController
  include FeatureFlags
  include Translatable
  include MapLocationAttributes
  include ImageAttributes

  feature_flag :offers, only: :index

  before_action :authenticate_user!, except: [:index, :show]

  def index
    authorize! :index, Offer

    @offers = Offer.listed_for(current_user)
                   .includes(:translations, :image, categories: :translations)
                   .sort_by_title
                   .page(params[:page])
  end

  def show
    @offer = Offer.find(params[:id])
    authorize! :show, @offer

    unless can?(:update, @offer)
      check_feature_flag(:offers)
      raise ActiveRecord::RecordNotFound if @offer.hidden?
    end
  end

  def new
    @offer = Offer.new
    authorize! :create, @offer
    prepare_form
  end

  def create
    @offer = Offer.new(offer_params.merge(author: current_user))
    assign_provider_on_create
    authorize! :create, @offer
    @offer.mark_for_review unless current_user.administrator?

    if @offer.save
      redirect_to offer_path(@offer), notice: t("custom.offers.create.success")
    else
      prepare_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @offer = Offer.find(params[:id])
    authorize! :update, @offer
    prepare_form
  end

  def update
    @offer = Offer.find(params[:id])
    authorize! :update, @offer
    @offer.provider = chosen_provider if current_user.administrator? && params[:offer].key?(:provider_id)
    @offer.mark_for_review unless current_user.administrator?

    saved = Offer.transaction do
      @offer.update(offer_params) || raise(ActiveRecord::Rollback)
    end

    if saved
      redirect_to offer_path(@offer), notice: t("custom.offers.update.success")
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  private

    def prepare_form
      @offer.build_image(user: current_user) unless @offer.image
      @offer.build_map_location unless @offer.map_location
      @categories_by_kind = Offer::Category.includes(:translations).group_by(&:kind)
      @providers = available_providers
    end

    def available_providers
      @available_providers ||= if current_user.administrator?
                                 Offer::Provider.order(:name)
                               else
                                 Offer::Provider.for_user(current_user).order(:name)
                               end
    end

    def chosen_provider
      provider_id = params.dig(:offer, :provider_id).presence
      available_providers.find_by(id: provider_id) if provider_id
    end

    def assign_provider_on_create
      if current_user.administrator?
        @offer.provider = chosen_provider
      else
        @offer.provider_required = true
        @offer.provider = chosen_provider || (available_providers.first if available_providers.one?)
      end
    end

    def offer_params
      params.require(:offer).permit(
        :address, :contact_name, :contact_phone, :contact_email, :contact_website,
        translation_params(Offer),
        category_ids: [],
        map_location_attributes: map_location_attributes,
        image_attributes: image_attributes
      )
    end
end

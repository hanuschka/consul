class OffersController < ApplicationController
  include FeatureFlags
  include Translatable
  include MapLocationAttributes
  include ImageAttributes

  feature_flag :offers, only: :index

  before_action :authenticate_user!, except: [:index, :show]

  def index
    authorize! :index, Offer

    @offers = Offer.includes(:translations, :image, categories: :translations)
                   .sort_by_title
                   .page(params[:page])
  end

  def show
    @offer = Offer.find(params[:id])
    authorize! :show, @offer
    check_feature_flag(:offers) unless can?(:update, @offer)
  end

  def new
    @offer = Offer.new
    authorize! :create, @offer
    prepare_form
  end

  def create
    @offer = Offer.new(offer_params.merge(author: current_user))
    authorize! :create, @offer

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

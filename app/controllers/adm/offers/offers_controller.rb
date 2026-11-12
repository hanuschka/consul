class Adm::Offers::OffersController < Adm::Offers::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :set_offer, only: [:edit, :update, :destroy]

  def index
    authorize Offer, :index?, policy_class: Adm::Offers::OfferPolicy

    @id_header_options = { sort: true }
    @title_header_options = { sort: true, search: true }
    @updated_at_header_options = { sort: true }

    @pagy, @offers = pagy(
      Adm::OffersQuery.new(
        policy_scope(Offer, policy_scope_class: Adm::Offers::OfferPolicy::Scope)
          .includes(:translations, :author, categories: :translations),
        params
      ).call
    )

    @breadcrumbs = [{ name: t("adm.offers.menu.items.offers"), icon: Adm::Section::ICONS["offers"][:material] }]
  end

  def edit
    prepare_form
  end

  def update
    saved = Offer.transaction do
      @offer.update(offer_params) || raise(ActiveRecord::Rollback)
    end

    if saved
      redirect_to adm_offers_root_path, notice: t(".success")
    else
      prepare_form
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @offer.destroy!
    redirect_to adm_offers_root_path, notice: t(".success")
  end

  private

    def set_offer
      @offer = Offer.find(params[:id])
      authorize @offer, policy_class: Adm::Offers::OfferPolicy
    end

    def prepare_form
      @offer.build_image(user: current_user) unless @offer.image
      @offer.build_map_location unless @offer.map_location
      @categories_by_kind = Offer::Category.includes(:translations).group_by(&:kind)

      @breadcrumbs = [
        { name: t("adm.offers.menu.items.offers"), url: adm_offers_root_path,
          icon: Adm::Section::ICONS["offers"][:material] },
        { name: @offer.title.presence || t("adm.offers.offers.edit.title") }
      ]
    end

    def offer_params
      params.require(:offer).permit(
        :title, :short_description, :times, :costs, :registration,
        :address, :contact_name, :contact_phone, :contact_email, :contact_website,
        category_ids: [],
        map_location_attributes: map_location_attributes,
        image_attributes: image_attributes
      )
    end
end

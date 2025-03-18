class Admin::SiteCustomization::ContentCardsController < Admin::SiteCustomization::BaseController
  include Translatable
  before_action :set_content_card, only: %i[edit update]

  def edit
    @default_settings = SiteCustomization::ContentCard.default_settings[@content_card.kind] || {}
  end

  def update
    if @content_card.update(content_card_params)
      @content_card.update!(settings: settings_params[:settings])
      redirect_to admin_homepage_path(anchor: "content-cards"), notice: t("admin.site_customization.content_cards.update.success")
    else
      render :edit
    end
  end

  def toggle_active
    enabled = ["1", "true"].include?(params[:site_customization_content_card][:active])
    @content_card = ::SiteCustomization::ContentCard.find(params[:site_customization_content_card][:id])

    @content_card.update!(active: enabled)
    head :ok
  end

  def order_content_cards
    ::SiteCustomization::ContentCard.order_content_cards(params[:ordered_list])
    head :ok
  end

  private

    def content_card_params
      params.require(:site_customization_content_card).permit(
        translation_params(SiteCustomization::ContentCard)
      )
    end

    def settings_params
      return { settings: {}} unless params[:site_customization_content_card][:settings].present?

      params.require(:site_customization_content_card).permit(
        settings: params[:site_customization_content_card][:settings].keys && permitted_setting_keys
      )
    end

    def set_content_card
      @content_card = SiteCustomization::ContentCard.find(params[:id])
    end

    def permitted_setting_keys
      SiteCustomization::ContentCard.default_settings.map { |_k, v| v.keys }.flatten.map(&:to_s)
    end
end

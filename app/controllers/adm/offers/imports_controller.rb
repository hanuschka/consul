class Adm::Offers::ImportsController < Adm::Offers::BaseController
  MAX_FILE_SIZE = 5.megabytes

  before_action :authorize_import
  before_action :set_breadcrumbs

  def new
  end

  def create
    file = params[:file]

    if file.blank? || !file.respond_to?(:read)
      flash.now[:alert] = t(".no_file")
      render :new, status: :unprocessable_entity
    elsif file.size > MAX_FILE_SIZE
      flash.now[:alert] = t(".too_large", max: helpers.number_to_human_size(MAX_FILE_SIZE))
      render :new, status: :unprocessable_entity
    else
      @result = Offers::CsvImport.call(file.read, author: current_user)
      render :new
    end
  end

  def template
    offers = policy_scope(Offer, policy_scope_class: Adm::Offers::OfferPolicy::Scope)
               .includes(:translations, :provider, :map_location, categories: :translations)
               .order(:id)
    send_data Offers::CsvExport.call(offers),
              filename: "#{t(".filename")}.csv",
              type: "text/csv; charset=utf-8"
  end

  def sample
    send_data Offers::CsvImport.sample,
              filename: "#{t(".filename")}.csv",
              type: "text/csv; charset=utf-8"
  end

  private

    def authorize_import
      authorize Offer, :import?, policy_class: Adm::Offers::OfferPolicy
    end

    def set_breadcrumbs
      @breadcrumbs = [
        { name: t("adm.offers.menu.items.offers"), url: adm_offers_root_path,
          icon: Adm::Section::ICONS["offers"][:material] },
        { name: t("adm.offers.imports.new.title") }
      ]
    end
end

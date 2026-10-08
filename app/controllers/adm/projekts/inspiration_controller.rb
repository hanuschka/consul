class Adm::Projekts::InspirationController < Adm::Projekts::BaseController
  before_action :authorize_inspiration, :load_breadcrumbs, :set_back_button_url

  def show
    @embed_url = "#{Dt.url}/?embedded_full=true" if Dt.url.present?
  end

  private

    def authorize_inspiration
      authorize [:adm, :projekts, :inspiration], :show?
    end

    def load_breadcrumbs
      @breadcrumbs = [{ name: t("adm.projekts.menu.items.inspiration"), icon: "travel_explore" }]
    end

    def set_back_button_url
      @back_button_url = previous_internal_path || adm_projekts_root_path
    end

    def previous_internal_path
      referer = request.referer
      return if referer.blank?

      uri = URI.parse(referer)
      return if uri.host.present? && uri.host != request.host
      return if uri.path == request.path

      [uri.path, uri.query].compact_blank.join("?")
    rescue URI::InvalidURIError
      nil
    end
end

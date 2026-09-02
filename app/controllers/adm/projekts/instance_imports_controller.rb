class Adm::Projekts::InstanceImportsController < Adm::Projekts::BaseController
  before_action :authorize_instance_import

  def new
    @breadcrumbs = [{ name: t("adm.projekts.menu.items.instance_import"), icon: "move_down" }]
  end

  # The admin browses app.demokratie.today in the inspiration frame and pastes
  # the address of a projekt worth reusing. Only its shape is checked here --
  # which instance it belongs to and whether it may be reused is resolved by
  # DT, which is the only party that knows every connected instance.
  def create
    if !valid_source_url?
      redirect_to new_adm_projekts_instance_import_path,
        alert: t("adm.projekts.projekts.instance_import.invalid_url")

      return
    end

    ::Projekts::CrossInstanceImport::DispatchImport.call(
      source_url: source_url, user: current_user
    )

    redirect_to adm_projekts_root_path,
      notice: t("adm.projekts.projekts.instance_import.started")
  end

  private

    def authorize_instance_import
      authorize [:adm, :projekts, Projekt], :create?
    end

    def source_url
      @source_url ||= params[:source_url].to_s.strip
    end

    def valid_source_url?
      return false if source_url.blank?

      uri = URI.parse(source_url)

      uri.is_a?(URI::HTTP) && uri.host.present?
    rescue URI::InvalidURIError
      false
    end
end

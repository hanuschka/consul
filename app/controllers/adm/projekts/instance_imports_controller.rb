class Adm::Projekts::InstanceImportsController < Adm::Projekts::BaseController
  # The admin browses app.demokratie.today in the inspiration frame and pastes
  # the address of a projekt worth reusing. Only its shape is checked here --
  # which instance it belongs to and whether it may be reused is resolved by
  # DT, which is the only party that knows every connected instance.
  def create
    authorize [:adm, :projekts, Projekt], :create?

    if !valid_source_url?
      redirect_to adm_projekts_inspiration_path,
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

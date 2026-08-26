class Adm::MachineTranslationsController < Adm::BaseController
  helper_method :feature_enabled?, :configured?

  def index
    authorize [:adm, RemoteTranslation], :index?, policy_class: Adm::MachineTranslationPolicy

    @usage = MachineTranslation::Stats.usage
    @rows_per_locale = MachineTranslation::Stats.rows_per_locale
    @chrome_rows_per_locale = MachineTranslation::Stats.chrome_rows_per_locale
    @pending_count = MachineTranslation::Stats.pending_count
    failures = policy_scope(MachineTranslation::Stats.failures,
                            policy_scope_class: Adm::MachineTranslationPolicy::Scope)
    @failures = failures.limit(20)
    @failures_count = failures.count
    @circuit_open = MachineTranslation::Stats.circuit_open?
    @target_locales = MachineTranslation.translatable_locales

    @breadcrumbs = [
      { name: t("adm.machine_translations.index.title"), icon: "translate" }
    ]
  end

  def destroy
    authorize [:adm, RemoteTranslation], :destroy?, policy_class: Adm::MachineTranslationPolicy

    locale = params[:id].to_s

    unless MachineTranslation.translatable_locales.map(&:to_s).include?(locale)
      redirect_to adm_machine_translations_path, alert: t("adm.machine_translations.flash.unknown_locale")
      return
    end

    deleted = MachineTranslation::Stats.purge_locale(locale)

    redirect_to adm_machine_translations_path,
      notice: t("adm.machine_translations.flash.purged", language: locale, count: deleted)
  end

  private

    def feature_enabled?
      MachineTranslation.enabled?
    end

    def configured?
      Deepl.configured?
    end
end

module Adm
  class BrevoMemberSyncController < Adm::BaseController
    # Status page for the member sync: whether it is configured, what the last runs did, and the
    # two things an admin can actually act on — trigger a sync, and read why one failed. The
    # configuration itself lives in config/secrets.yml and is deliberately not editable here.
    RECENT_RUNS = 20

    def show
      authorize [:adm, :brevo_member_sync]

      @sync_logs = BrevoSyncLog.recent.includes(:triggered_by).limit(RECENT_RUNS)
      @last_completed_run = BrevoSyncLog.status_completed.recent.first
      @member_count = User.brevo_members.count
      @breadcrumbs = index_breadcrumbs
    end

    def create
      authorize [:adm, :brevo_member_sync], :create?

      unless Brevo::Settings.sync_enabled?
        return redirect_to adm_brevo_member_sync_path, alert: t(".not_configured")
      end

      Brevo::MemberSyncJob.perform_later("manual", current_user.id)

      redirect_to adm_brevo_member_sync_path, notice: t(".enqueued")
    end

    def log
      authorize [:adm, :brevo_member_sync], :log?

      @sync_log = BrevoSyncLog.find(params[:id])
      @breadcrumbs = index_breadcrumbs + [{ name: t(".title") }]
    end

    private

      def index_breadcrumbs
        [
          { name: t("adm.menu.items.users"), icon: "3p", url: adm_users_path },
          { name: t("adm.brevo_member_sync.show.title"), url: adm_brevo_member_sync_path }
        ]
      end
  end
end

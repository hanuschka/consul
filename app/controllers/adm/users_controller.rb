module Adm
  class UsersController < Adm::BaseController
    def index
      authorize [:adm, User]
      base_scope = UsersQuery.call(policy_scope([:adm, User]), params)

      respond_to do |format|
        format.html do
          @pagy, @users = pagy(base_scope)

          @username_header_options = { sort: true, search: true }
          gender_options = policy_scope([:adm, User]).distinct.pluck(:gender).index_by(&:itself)
          @gender_header_options = { filter_options: gender_options }
          @reverify_header_options = { filter_options: { true => t("shared.true"), false => t("shared.false") }}

          @breadcrumbs = [
            { name: t("adm.menu.items.profiles"), icon: "3p" },
            { name: t("adm.menu.items.profiles_subitems.users") }
          ]
        end

        format.csv do
          CsvJobs::UsersJob.perform_later(current_user.id, base_scope.pluck(:id), request.base_url)
          redirect_to adm_users_path, notice: t("adm.users.index.csv_export_notice")
        end
      end
    end

    def csv_download
      authorize [:adm, User], :index?
      date = params[:date].to_s

      unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        redirect_to adm_users_path, alert: t("adm.users.csv_download.not_found")
        return
      end

      file_path = Rails.root.join("tmp/csv_exports/users_#{current_user.id}_#{date}.csv")

      if File.exist?(file_path)
        send_file file_path, filename: "users_export.csv", type: "text/csv"
      else
        redirect_to adm_users_path, alert: t("adm.users.csv_download.not_found")
      end
    end
  end
end

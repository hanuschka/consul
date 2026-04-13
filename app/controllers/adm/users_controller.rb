module Adm
  class UsersController < Adm::BaseController
    def index
      authorize [:adm, User]
      base_scope = UsersQuery.call(policy_scope([:adm, User]), params)
        .includes(:registered_address, :administrator, :moderator, :valuator, :manager, :poll_officer, :organization)

      respond_to do |format|
        format.html do
          @pagy, @users = pagy(base_scope)

          @username_header_options = { sort: true, search: true }
          @email_header_options = { search: true }
          @first_name_header_options = { search: true }
          @last_name_header_options = { search: true }
          @city_name_header_options = { sort: true }
          @created_at_header_options = { sort: true }
          @verified_at_header_options = { sort: true }

          gender_options = policy_scope([:adm, User]).distinct.pluck(:gender).compact.index_by(&:itself)
          @gender_header_options = { filter_options: gender_options }
          @reverify_header_options = { filter_options: { true => t("shared.true"), false => t("shared.false") } }

          document_type_options = policy_scope([:adm, User]).distinct.pluck(:document_type).compact.index_by(&:itself)
          @document_type_header_options = { filter_options: document_type_options }

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

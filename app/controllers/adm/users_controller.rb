module Adm
  class UsersController < Adm::BaseController
    def index
      authorize [:adm, User]
      base_scope = UsersQuery.call(policy_scope([:adm, User]).order(created_at: :desc), params)
        .includes(:registered_address, :administrator, :moderator, :valuator, :manager, :poll_officer, :organization)

      respond_to do |format|
        format.html do
          @pagy, @users = pagy(base_scope, limit: 20)

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
            { name: t("adm.menu.items.users"), icon: "3p" }
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

    def edit
      @user = User.find(params[:id])
      authorize [:adm, @user]

      @breadcrumbs = edit_breadcrumbs
    end

    def update
      @user = User.find(params[:id])
      authorize [:adm, @user]

      # Email changes made by an admin here are confirmed immediately: write the
      # new address straight to :email (skipping Devise's reconfirmation flow)
      # so it takes effect at once and is captured by the audit log.
      @user.skip_reconfirmation!

      if @user.update(user_params)
        # Only reverify when Melderegister is enabled — otherwise reverify!
        # unverifies the user and hits the remote census API for nothing.
        if params[:reverify].present? && Setting["feature.melderegister"].present?
          @user.reverify!
          @user.update!(reverify: true)
        end

        redirect_to adm_users_path, notice: t("adm.users.flash.updated")
      else
        @breadcrumbs = edit_breadcrumbs

        render :edit, status: :unprocessable_entity
      end
    end

    def audits
      @user = User.find(params[:id])
      authorize [:adm, @user]

      @breadcrumbs = audits_breadcrumbs
    end

    def destroy
      @user = User.find(params[:id])
      authorize [:adm, @user]

      @user.erase(
        "Gelöscht von #{current_user.username} (id: #{current_user.id})"
      )

      redirect_to adm_users_path, notice: t("adm.users.flash.deleted")
    end

    def verify
      @user = User.find(params[:id])
      authorize [:adm, @user]

      if @user.verify!
        @user.update!(reverify: false)
        Mailer.manual_verification_confirmation(@user).deliver_later

        redirect_to adm_users_path, notice: t("adm.users.flash.verified")
      else
        redirect_to adm_users_path, alert: t("adm.users.flash.verify_failed")
      end
    end

    def unverify
      @user = User.find(params[:id])
      authorize [:adm, @user]

      @user.unverify!
      @user.update!(reverify: false)

      redirect_to adm_users_path, notice: t("adm.users.flash.unverified")
    end

    private

      def user_params
        params.require(:user).permit(
          :email,
          :first_name, :last_name,
          :city_name, :plz, :street_name, :street_number, :street_number_extension,
          :gender, :date_of_birth
        )
      end

      def edit_breadcrumbs
        [
          { name: t("adm.menu.items.users"), icon: "3p", url: adm_users_path },
          { name: @user.name.presence || @user.email }
        ]
      end

      def audits_breadcrumbs
        [
          { name: t("adm.menu.items.users"), icon: "3p", url: adm_users_path },
          { name: @user.name.presence || @user.email, url: edit_adm_user_path(@user) },
          { name: t("adm.shared.audits.title") }
        ]
      end
  end
end

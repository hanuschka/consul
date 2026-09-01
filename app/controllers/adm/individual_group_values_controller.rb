module Adm
  class IndividualGroupValuesController < Adm::BaseController
    before_action :load_individual_group
    before_action :load_individual_group_value, only: [
      :show, :edit, :update, :destroy, :search_user, :add_user, :add_email,
      :add_from_csv, :remove_user, :remove_email_from_auto_join_emails
    ]

    def show
      authorize [:adm, @individual_group_value]
      @pagy, @related_users = pagy(
        @individual_group_value.users.order("user_individual_group_values.id": :desc)
      )

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.individual_groups"), url: adm_individual_groups_path },
        { name: @individual_group.name, url: adm_individual_group_path(@individual_group) },
        { name: @individual_group_value.name }
      ]
    end

    def new
      @individual_group_value = IndividualGroupValue.new
      authorize [:adm, @individual_group_value]

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.individual_groups"), url: adm_individual_groups_path },
        { name: @individual_group.name, url: adm_individual_group_path(@individual_group) },
        { name: t(".title") }
      ]
    end

    def create
      @individual_group_value = IndividualGroupValue.new(individual_group_value_params)
      authorize [:adm, @individual_group_value]

      if @individual_group_value.save
        redirect_to adm_individual_group_path(@individual_group), notice: t(".success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize [:adm, @individual_group_value]

      @breadcrumbs = [
        { name: t("adm.menu.items.application"), icon: "desktop_windows" },
        { name: t("adm.menu.items.application_subitems.individual_groups"), url: adm_individual_groups_path },
        { name: @individual_group.name, url: adm_individual_group_path(@individual_group) },
        { name: t(".title") }
      ]
    end

    def update
      authorize [:adm, @individual_group_value]

      if @individual_group_value.update(individual_group_value_params)
        redirect_to adm_individual_group_path(@individual_group), notice: t(".success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize [:adm, @individual_group_value]
      @individual_group_value.destroy!
      redirect_to adm_individual_group_path(@individual_group), notice: t(".success")
    end

    def search_user
      authorize [:adm, @individual_group_value]
      @users = User.search(params[:search]).limit(20)
    end

    def add_user
      authorize [:adm, @individual_group_value]
      @user = User.find(params[:user_id])
      @individual_group_value.add_user(@user)

      redirect_to adm_individual_group_value_path(@individual_group, @individual_group_value)
    end

    def add_email
      authorize [:adm, @individual_group_value]
      redirect_path = adm_individual_group_value_path(@individual_group, @individual_group_value)
      email = params[:email].to_s

      if !email.match?(URI::MailTo::EMAIL_REGEXP)
        redirect_to redirect_path, alert: t(".invalid")
      elsif @individual_group_value.stored_email?(email)
        redirect_to redirect_path, notice: t(".already_stored")
      else
        @individual_group_value.add_email(email)
        redirect_to redirect_path, notice: t(".success")
      end
    end

    def add_from_csv
      authorize [:adm, @individual_group_value]
      redirect_path = adm_individual_group_value_path(@individual_group, @individual_group_value)

      if params[:file].nil?
        redirect_to redirect_path, alert: t(".no_file")
      elsif !params[:file].original_filename.ends_with?(".csv")
        redirect_to redirect_path, alert: t(".invalid_format")
      else
        new_file_path = save_file_in_tmp(params[:file])
        CsvJobs::AddUsersToIndividualGroupValues.perform_later(current_user.id, @individual_group_value.id, new_file_path)
        redirect_to redirect_path, notice: t(".success")
      end
    end

    def remove_user
      authorize [:adm, @individual_group_value]
      @user = User.find(params[:user_id])
      @individual_group_value.users.destroy(@user)

      redirect_to adm_individual_group_value_path(@individual_group, @individual_group_value)
    end

    def remove_email_from_auto_join_emails
      authorize [:adm, @individual_group_value]
      @individual_group_value.remove_auto_join_email(params[:email])

      redirect_to adm_individual_group_value_path(@individual_group, @individual_group_value)
    end

    private

      def load_individual_group
        @individual_group = IndividualGroup.find(params[:individual_group_id])
      end

      def load_individual_group_value
        @individual_group_value = IndividualGroupValue.find(params[:id])
      end

      def individual_group_value_params
        params.require(:individual_group_value).permit(:individual_group_id, :name, :email_pattern)
      end

      def save_file_in_tmp(uploaded_file)
        new_file_path = "/tmp/#{SecureRandom.uuid}.csv"

        File.open(new_file_path, "wb") do |file|
          file.write(uploaded_file.read)
        end

        new_file_path
      end
  end
end

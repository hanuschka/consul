class Adm::Officing::BaseController < Adm::BaseController
  include HasRegisteredAddress

  before_action :set_officing_manager
  before_action :authorize_officing_access

  def verify_user
    authorize :base, policy_class: Adm::Officing::BasePolicy
    @offline_user = User.new
    render "adm/officing/shared/verify_user"
  end

  def do_verify_user
    authorize :base, policy_class: Adm::Officing::BasePolicy

    if params[:skip_verification].present?
      offline_user = User.create!(
        erased_at:                Time.current,
        email:                    nil,
        skip_password_validation: true,
        terms_data_storage:       "1",
        terms_data_protection:    "1",
        terms_general:            "1"
      )

      redirect_to officing_desk_path(offline_user)
    else
      @offline_user = User.new(user_params)
      process_temp_attributes_for(@offline_user)

      unique_stamp = @offline_user.prepare_unique_stamp

      if unique_stamp.blank?
        flash.now[:error] = t("adm.officing.verification.errors.missing_fields")
        render "adm/officing/shared/verify_user", status: :unprocessable_entity
      else
        existing_user = User.find_by(unique_stamp: unique_stamp)
        @offline_user = existing_user if existing_user.present?

        if (Setting["feature.melderegister"] && @offline_user.send(:residency_valid?)) || params[:mark_as_verified].present?
          if @offline_user.new_record?
            @offline_user.verified_at = Time.current
            @offline_user.unique_stamp = unique_stamp
          else
            @offline_user.update_column(:verified_at, Time.current)
          end
        end

        if @offline_user.new_record?
          @offline_user.email = nil
          @offline_user.erased_at = Time.current
          @offline_user.password = "Aa1" + (0...17).map { ("a".."z").to_a[rand(26)] }.join
          @offline_user.terms_data_storage = "1"
          @offline_user.terms_data_protection = "1"
          @offline_user.terms_general = "1"
          @offline_user.save!
        end

        redirect_to officing_desk_path(@offline_user)
      end
    end
  end

  private

    def adm_menu_component
      Adm::Officing::MenuComponent.new
    end

    def load_budget
      @budget = Budget.find(params[:budget_id])
    end

    def load_offline_user
      @offline_user = User.find(params[:offline_user_id])
    end

    def set_officing_manager
      @officing_manager = current_user.officing_manager
    end

    def authorize_officing_access
      authorize :base, :index?, policy_class: Adm::Officing::BasePolicy
    end

    def user_params
      set_address_attributes

      params.require(:user).permit(:first_name, :last_name,
                                   :city_name, :plz, :street_name, :street_number, :street_number_extension,
                                   :registered_address_id,
                                   :gender, :date_of_birth)
    end

    # Subclasses must implement this to redirect after verification
    def officing_desk_path(offline_user)
      raise NotImplementedError
    end
end

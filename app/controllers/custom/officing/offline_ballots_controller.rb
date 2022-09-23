class Officing::OfflineBallotsController < Officing::BaseController
  def verify_user
  end

  def find_or_create_user
    if params[:first_name].blank? || params[:last_name].blank? || params[:plz].blank?
      flash.now[:error] = "Please make sure all fields are filled in"
      render :verify_user
    else
      @user = User.find_or_initialize_by(
        first_name: params[:first_name],
        last_name: params[:last_name],
        plz: params[:plz]
      )

      unless @user.persisted?
        @user.verified_at = Time.current
        @user.erased_at = Time.current
        @user.password = (0...20).map { ("a".."z").to_a[rand(26)] }.join
        @user.terms_of_service = "1"
        # @user.date_of_birth =
        @user.geozone = Geozone.find_with_plz(params[:plz])
        @user.save!
      end

      redirect_to officing_offline_ballots_investments_path(params[:budget_id], user_id: @user.id)
    end
  end

  def investments
    @user = User.find(params[:user_id])
    @budget = Budget.find(params[:budget_id])
    @heading = @budget.headings.sort_by_name.first
    @ballot = Budget::Ballot.where(user: @user, budget: @budget).first_or_create!
    @investments = @budget.investments
    @investment_ids = @investments.ids
  end
end

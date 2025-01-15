class Admin::RecipientGroupsController < Admin::BaseController
  load_and_authorize_resource

  def index
    @recipient_groups = RecipientGroup.order(created_at: :desc).page(params[:page])
  end

  # def create
  #   @recipient_group = RecipientGroup.new(recipient_group_params)
  #   if @recipient_group.save
  #     redirect_to admin_recipient_groups_path, notice: t("custom.admin.recipient_groups.create.notice")
  #   else
  #     render :new
  #   end
  # end

  # def update
  #   if @recipient_group.update(recipient_group_params)
  #     redirect_to admin_recipient_groups_path, notice: t("custom.admin.recipient_groups.update.notice")
  #   else
  #     render :edit
  #   end
  # end

  # def destroy
  #   @recipient_group.destroy!
  #   redirect_to admin_recipient_groups_path, notice: t("custom.admin.recipient_groups.destroy.notice")
  # end

  # private

  #   def recipient_group_params
  #     params.require(:recipient_group).permit(allowed_params)
  #   end

  #   def allowed_params
  #     [:active_from, :active_to,
  #      translation_params(RecipientGroup)]
  #   end
end

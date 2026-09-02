module Adm
  class SystemUserController < Adm::BaseController
    def edit
      @user = User.system
      authorize [:adm, @user]

      @breadcrumbs = edit_breadcrumbs
    end

    def update
      @user = User.system
      authorize [:adm, @user]

      if @user.update(system_user_params)
        redirect_to edit_adm_system_user_path, notice: t(".success")
      else
        @breadcrumbs = edit_breadcrumbs

        render :edit, status: :unprocessable_entity
      end
    end

    private

      def system_user_params
        params.require(:user).permit(
          :username,
          :background_image,
          image_attributes: [:id, :attachment, :cached_attachment, :ai_generated, :user_id, :_destroy]
        )
      end

      def edit_breadcrumbs
        [
          { name: t("adm.menu.items.application"), icon: "desktop_windows" },
          { name: t("adm.system_user.edit.title") }
        ]
      end
  end
end

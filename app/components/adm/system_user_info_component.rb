class Adm::SystemUserInfoComponent < ApplicationComponent
  def initialize(user:, kind: :system, show_edit_link: true)
    @user = user
    @kind = kind
    @show_edit_link = show_edit_link
  end

  private

    attr_reader :user, :kind

    def name
      user.name
    end

    def label
      if api_client_kind?
        t(".api_client_label")
      else
        t(".label")
      end
    end

    def css_classes
      class_names("adm-system-user-info", "-api-client": api_client_kind?)
    end

    def api_client_kind?
      kind == :api_client
    end

    def show_system_user_tag?
      !api_client_kind?
    end

    def edit_url
      helpers.edit_adm_system_user_path
    end

    def show_edit_link?
      @show_edit_link && !api_client_kind?
    end
end

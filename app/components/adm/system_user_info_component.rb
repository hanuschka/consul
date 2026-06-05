class Adm::SystemUserInfoComponent < ApplicationComponent
  def initialize(user:, kind: :system, show_edit_link: true, size: :default)
    @user = user
    @kind = kind
    @show_edit_link = show_edit_link
    @size = size
  end

  private

    attr_reader :user, :kind, :size

    def name
      user.full_name
    end

    def label
      if api_client_kind?
        t(".api_client_label")
      elsif small?
        t(".system_user_tag")
      else
        t(".label")
      end
    end

    def css_classes
      class_names("adm-system-user-info", "-api-client": api_client_kind?, "-small": small?)
    end

    def api_client_kind?
      kind == :api_client
    end

    def small?
      size == :small
    end

    def show_system_user_tag?
      !api_client_kind? && !small?
    end

    def edit_url
      helpers.edit_adm_system_user_path
    end

    def show_edit_link?
      @show_edit_link && !api_client_kind? && !small?
    end
end

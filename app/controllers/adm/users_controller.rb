module Adm
  class UsersController < Adm::BaseController
    def index
      authorize [:adm, User]
      base_scope = UsersQuery.call(policy_scope([:adm, User]), params)

      @pagy, @users = pagy(base_scope)

      @username_header_options = { sort: true, search: true }
      gender_options = policy_scope([:adm, User]).distinct.pluck(:gender).index_by(&:itself)
      @gender_header_options = { filter_options: gender_options }
      @reverify_header_options = { filter_options: { true => t("shared.true"), false => t("shared.false") }}

      @breadcrumbs = [
        { name: t("adm.menu.items.profiles") },
        { name: t("adm.menu.items.profiles_subitems.users") }
      ]
    end
  end
end

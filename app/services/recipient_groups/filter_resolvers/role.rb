module RecipientGroups
  module FilterResolvers
    class Role < Base
      ROLE_SCOPES = {
        "administrator"             => :administrators,
        "moderator"                 => :moderators,
        "valuator"                  => :valuators,
        "projekt_manager"           => :projekt_managers,
        "idea_manager"              => :idea_managers,
        "officing_manager"          => :officing_managers,
        "deficiency_report_manager" => :deficiency_report_managers
      }.freeze

      def emails
        scope = ROLE_SCOPES[params[:role].to_s]
        return [] unless scope

        User.actual.public_send(scope).pluck(:email).compact.uniq
      end
    end
  end
end

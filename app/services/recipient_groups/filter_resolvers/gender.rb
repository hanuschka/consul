module RecipientGroups
  module FilterResolvers
    class Gender < Base
      ALLOWED = %w[male female other_gen].freeze

      def emails
        value = params[:gender].to_s
        return [] unless ALLOWED.include?(value)

        User.actual.where(gender: value).pluck(:email).compact.uniq
      end
    end
  end
end

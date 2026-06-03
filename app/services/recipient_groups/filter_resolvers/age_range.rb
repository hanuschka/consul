module RecipientGroups
  module FilterResolvers
    class AgeRange < Base
      def emails
        min, max = resolve_bounds
        return [] if min.nil? && max.nil?

        today = Date.current
        scope = User.actual.where.not(date_of_birth: nil)
        scope = scope.where("date_of_birth <= ?", today - min.years) if min
        scope = scope.where("date_of_birth >= ?", today - (max + 1).years + 1.day) if max

        scope.pluck(:email).compact.uniq
      end

      private

        def resolve_bounds
          if params[:age_range_id].present?
            range = ::AgeRange.find_by(id: params[:age_range_id])
            return [nil, nil] unless range

            [range.min_age, range.max_age]
          else
            [params[:min_age]&.to_i, params[:max_age]&.to_i]
          end
        end
    end
  end
end

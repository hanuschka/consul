module RecipientGroups
  module FilterResolvers
    class District < Base
      def emails
        ids = Array(params[:district_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        User.actual.joins(:registered_address).where(registered_addresses: { registered_address_district_id: ids }).pluck(:email).compact.uniq
      end
    end
  end
end

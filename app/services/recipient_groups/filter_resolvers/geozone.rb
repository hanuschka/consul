module RecipientGroups
  module FilterResolvers
    class Geozone < Base
      def emails
        ids = Array(params[:geozone_ids]).map(&:to_i).reject(&:zero?)
        return [] if ids.empty?

        User.actual.where(geozone_id: ids).pluck(:email).compact.uniq
      end
    end
  end
end

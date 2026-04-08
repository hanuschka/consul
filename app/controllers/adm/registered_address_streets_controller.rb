module Adm
  class RegisteredAddressStreetsController < Adm::BaseController
    def search
      authorize [:adm, ::RegisteredAddress::Street]

      @streets = if params[:query].present? && params[:query].length >= 2
                   ::RegisteredAddress::Street
                     .where("name ILIKE ?", "%#{params[:query]}%")
                     .where.not(id: selected_ids)
                     .limit(4)
                 else
                   ::RegisteredAddress::Street.none
                 end

      respond_to do |format|
        format.turbo_stream
      end
    end

    private

      def selected_ids
        Array(params[:selected_ids]).map(&:to_i)
      end
  end
end

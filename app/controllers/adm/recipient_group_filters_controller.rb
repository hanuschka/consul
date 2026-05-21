module Adm
  class RecipientGroupFiltersController < Adm::BaseController
    before_action :set_recipient_group
    before_action :set_filter, only: [:update, :destroy]

    def create
      authorize [:adm, @recipient_group], :create_filter?
      @filter = @recipient_group.filters.create(filter_params)

      respond_to { |f| f.turbo_stream }
    end

    def update
      authorize [:adm, @recipient_group], :update_filter?
      @filter.update(merged_filter_params)

      respond_to { |f| f.turbo_stream }
    end

    def destroy
      authorize [:adm, @recipient_group], :destroy_filter?
      @filter.destroy

      respond_to { |f| f.turbo_stream }
    end

    def reorder
      authorize [:adm, @recipient_group], :reorder_filters?

      ordered_ids = params[:ordered_ids].map(&:to_i)
      ordered_ids.each_with_index do |id, idx|
        @recipient_group.filters.where(id: id).update_all(position: idx + 1)
      end

      respond_to { |f| f.turbo_stream }
    end

    def recount
      authorize [:adm, @recipient_group], :recount_filters?
      @resolver = RecipientGroupResolver.new(@recipient_group)

      respond_to { |f| f.turbo_stream }
    end

    private

      def set_recipient_group
        @recipient_group = RecipientGroup.find(params[:recipient_group_id])
      end

      def set_filter
        @filter = @recipient_group.filters.find(params[:id])
      end

      def filter_params
        params.require(:recipient_group_filter)
              .permit(:kind, :operator, params: {})
      end

      # PATCH updates send a single changed field. Merge into existing params
      # instead of replacing the whole JSONB hash, so other keys are preserved.
      def merged_filter_params
        attrs = filter_params
        return attrs unless attrs[:params].is_a?(ActionController::Parameters) || attrs[:params].is_a?(Hash)

        incoming = attrs[:params].to_h.stringify_keys
        existing = (@filter.params || {}).stringify_keys
        attrs.merge(params: existing.merge(incoming))
      end
  end
end

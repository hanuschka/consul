module Adm
  class RecipientGroupFilterCardComponent < ApplicationComponent
    def initialize(filter:, count: 0, delta: 0, display_position: nil)
      @filter = filter
      @count = count.to_i
      @delta = delta.to_i
      @display_position = display_position
    end

    private

      attr_reader :filter, :count, :delta

      def display_position
        @display_position || filter.position
      end

      def first_filter?
        return true if display_position.to_i <= 1

        filter.recipient_group.filters.where("position < ?", filter.position).none?
      end

      def filter_params
        filter.params.is_a?(Hash) ? filter.params : {}
      end

      def delta_class
        return nil if delta.zero?

        delta.positive? ? "rg-filter-card__delta--positive" : "rg-filter-card__delta--negative"
      end

      def delta_label
        if delta.positive?
          t("adm.recipient_groups.filters.counter.delta_plus", count: delta)
        else
          t("adm.recipient_groups.filters.counter.delta_minus", count: delta.abs)
        end
      end
  end
end

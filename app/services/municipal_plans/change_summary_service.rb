module MunicipalPlans
  # What a pending version changes against the released one, so the Dashboard-Administration can
  # see what it is about to release. Formatting is left to the view: every change carries the kind
  # of value it holds.
  class ChangeSummaryService < ApplicationService
    Change = Struct.new(:field, :label, :kind, :before, :after, keyword_init: true)

    RICH_TEXT_FIELDS = %w[
      short_description
      further_information
      last_resolution
      processing_status
      next_steps
      formal_participation_reason
      informal_participation_reason
    ].freeze

    BOOLEAN_FIELDS = %w[formal_participation informal_participation].freeze

    def initialize(working_copy)
      @copy = working_copy
    end

    def call
      return [] unless copy.working_copy?

      attribute_changes + responsible_change + list_changes + map_location_change
    end

    private

      attr_reader :copy

      def released
        copy.released_plan
      end

      def compared_fields
        MunicipalPlan.content_attribute_names + %w[internal_notes]
      end

      def attribute_changes
        compared_fields.filter_map do |field|
          before = released.public_send(field)
          after = copy.public_send(field)
          next if before.to_s == after.to_s

          change(field, kind_for(field), before, after)
        end
      end

      def responsible_change
        return [] if released.responsible == copy.responsible

        [change("responsible", :text, released.responsible&.name, copy.responsible&.name)]
      end

      def list_changes
        [
          list_change("districts", ->(plan) { plan.districts.map(&:name_for_display).sort }),
          list_change("topics", ->(plan) { plan.topics.map(&:name).sort }),
          list_change("links", ->(plan) { plan.links.map { |l| "#{l.title} (#{l.url})" }.sort })
        ].compact
      end

      def list_change(field, values)
        before = values.call(released)
        after = values.call(copy)
        return if before == after

        change(field, :list, before, after)
      end

      def map_location_change
        before = map_location_values(released)
        after = map_location_values(copy)
        return [] if before == after

        [change("map_location", :map, before, after)]
      end

      def map_location_values(plan)
        return nil if plan.map_location.blank?

        plan.map_location.attributes.slice("latitude", "longitude", "zoom", "features")
      end

      def kind_for(field)
        return :rich_text if RICH_TEXT_FIELDS.include?(field)
        return :boolean if BOOLEAN_FIELDS.include?(field)

        :text
      end

      def change(field, kind, before, after)
        Change.new(field: field, label: MunicipalPlan.human_attribute_name(field), kind: kind,
                   before: before, after: after)
      end
  end
end

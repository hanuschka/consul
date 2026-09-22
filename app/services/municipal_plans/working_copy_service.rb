module MunicipalPlans
  # A released Vorhaben is never edited in place: the Sachbearbeitung works on a copy that carries
  # the same content but stays out of the public list until the Dashboard-Administration releases
  # it. The copy is an ordinary Entwurf, so the existing form, policies and validations apply to it
  # unchanged, and the public scope excludes it by status.
  class WorkingCopyService < ApplicationService
    # Everything the copy leaves behind: the workflow fields belong to the released Vorhaben and
    # keep being edited there, never through a release.
    UNCOPIED_ATTRIBUTES = %w[
      id
      status
      version
      content_updated_at
      given_order
      released_plan_id
      submitted_at
      tsv
      created_at
      updated_at
    ].freeze

    def initialize(municipal_plan)
      @municipal_plan = municipal_plan
    end

    def call
      return municipal_plan if municipal_plan.working_copy?
      return municipal_plan.working_copy if municipal_plan.working_copy.present?

      MunicipalPlan.transaction { build_copy.tap(&:save!) }
    end

    private

      attr_reader :municipal_plan

      def build_copy
        copy = MunicipalPlan.new(municipal_plan.attributes.except(*UNCOPIED_ATTRIBUTES))
        copy.released_plan = municipal_plan
        copy.status = "draft"
        copy.version = municipal_plan.version
        copy.content_updated_at = municipal_plan.content_updated_at

        copy_translations(copy)
        copy_assignments(copy)
        copy_links(copy)
        copy_map_location(copy)
        copy
      end

      def copy_translations(copy)
        municipal_plan.translations.each do |translation|
          copy.translations.build(
            translation.attributes.except("id", "municipal_plan_id", "created_at", "updated_at")
          )
        end
      end

      def copy_assignments(copy)
        municipal_plan.district_assignments.each do |assignment|
          copy.district_assignments.build(
            registered_address_district_id: assignment.registered_address_district_id
          )
        end

        municipal_plan.topic_assignments.each do |assignment|
          copy.topic_assignments.build(municipal_plan_topic_id: assignment.municipal_plan_topic_id)
        end
      end

      def copy_links(copy)
        municipal_plan.links.each do |link|
          copy.links.build(link.attributes.except("id", "municipal_plan_id", "created_at",
                                                  "updated_at"))
        end
      end

      def copy_map_location(copy)
        return if municipal_plan.map_location.blank?

        copy.build_map_location(
          municipal_plan.map_location.attributes.except("id", "mappable_id", "mappable_type")
        )
      end
  end
end

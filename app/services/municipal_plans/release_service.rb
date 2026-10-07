module MunicipalPlans
  # Makes the version the Sachbearbeitung handed in public. For a first publication that is the
  # Entwurf itself; for a later change it is the working copy, whose content moves onto the
  # released Vorhaben so its id, its editorial position and the links pointing at it survive.
  class ReleaseService < ApplicationService
    def initialize(municipal_plan)
      @submission = municipal_plan
      @released = municipal_plan.released_plan || municipal_plan
    end

    def call
      MunicipalPlan.transaction do
        associations_before = association_fingerprint

        # Archiving is the Sachbearbeitung's decision and stands on its own: releasing a change to
        # an archived Vorhaben updates its content without putting it back into the public list.
        released.status = "published" unless released.archived?
        released.submitted_at = nil

        if first_publication?
          released.released_at = Time.current
          released.save!
        else
          without_auditing do
            apply_content
            released.save!
          end
        end

        version_advanced = released.saved_change_to_version?
        associations_changed = association_fingerprint(reload: true) != associations_before

        released.register_content_change! if associations_changed && !version_advanced

        unless first_publication?
          move_audits_to_released
          released.update!(released_at: Time.current)
          submission.destroy!
        end
      end

      released
    end

    private

      attr_reader :submission, :released

      def first_publication?
        submission == released
      end

      def without_auditing(&block)
        MunicipalPlan.without_auditing do
          MunicipalPlan.translation_class.without_auditing(&block)
        end
      end

      def move_audits_to_released
        submission.audits.where(action: "update").update_all(auditable_id: released.id)

        submission.translations.each do |translation|
          target = released.translations.find_by(locale: translation.locale)
          next if target.blank?

          translation.audits.where(action: "update")
                     .update_all(auditable_id: target.id, associated_id: released.id)
        end
      end

      def apply_content
        released.assign_attributes(
          submission.attributes.except(*WorkingCopyService::UNCOPIED_ATTRIBUTES)
        )

        apply_translations
        apply_assignments
        apply_links
        apply_map_location
      end

      def apply_translations
        submission.translations.each do |translation|
          attributes = translation.attributes.except("id", "municipal_plan_id", "created_at",
                                                     "updated_at")
          existing = released.translations.find { |t| t.locale.to_s == translation.locale.to_s }

          existing ? existing.assign_attributes(attributes) : released.translations.build(attributes)
        end
      end

      def apply_assignments
        released.district_ids = submission.district_ids
        released.topic_ids = submission.topic_ids
      end

      def apply_links
        released.links.destroy_all

        submission.links.each do |link|
          released.links.create!(link.attributes.except("id", "municipal_plan_id", "created_at",
                                                        "updated_at"))
        end
      end

      def apply_map_location
        return if submission.map_location.blank?

        attributes = submission.map_location.attributes.except("id", "mappable_id", "mappable_type")

        if released.map_location.present?
          released.map_location.update!(attributes)
        else
          released.build_map_location(attributes)
        end
      end

      # Ortsteile, Themen and Links are content too, but they change through associations, so a
      # save of the Vorhaben itself does not see them.
      def association_fingerprint(reload: false)
        plan = reload ? released.reload : released

        [plan.district_ids.sort, plan.topic_ids.sort,
         plan.links.map { |link| [link.title, link.url, link.given_order] }.sort]
      end
  end
end

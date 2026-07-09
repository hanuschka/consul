module Adm::ContextedClonesRegeneration
  extend ActiveSupport::Concern

  private

    # Rebuilds the contexted clones for the given contextualised questions after a
    # /adm edit, unless the poll already has voters (regeneration destroys and
    # recreates the clone questions, discarding any votes cast on them). Sets a
    # warning flash when it had to skip, pointing admins to the manual regenerate
    # action.
    def regenerate_contexted_clones_for(*questions)
      targets = questions.flatten.compact.select(&:contextualize_by_question)
      return if targets.none?

      results = targets.map(&:regenerate_contexted_clones_if_safe)

      if results.any? { |regenerated| regenerated == false }
        flash[:alert] = t("adm.projekts.poll_questions.contexted_clones.skipped")
      end
    end
end

# Imports of different documents used to open with the same template and then
# follow the same sequence. Asking the model to vary did not hold, so the
# templates the latest imports opened with are not offered to the next one at
# all. The output schema only accepts offered ids, and a page that cannot use a
# recent opener cannot repeat a recent sequence either.
#
# A category is never thinned out for this. Where a small catalogue leaves no
# room, the oldest openers stay on offer and that import may repeat one.
class ProjektImports::WithholdRecentOpeningTemplatesService < ApplicationService
  MIN_TEMPLATES_PER_CATEGORY = 3

  def initialize(templates:, recent_opening_template_ids:)
    @templates = Array(templates)
    @recent_opening_template_ids = Array(recent_opening_template_ids).uniq
  end

  def call
    withheld_template_ids = template_ids_to_withhold

    @templates.reject { |template| withheld_template_ids.include?(template["id"]) }
  end

  private

    # Walked newest opener first, so the floor gives up the oldest ones.
    def template_ids_to_withhold
      category_ids = @templates.to_h { |template| [template["id"], template["category_id"]] }
      offered_counts = category_ids.values.tally
      withheld_template_ids = []

      @recent_opening_template_ids.each do |template_id|
        category_id = category_ids[template_id]

        if category_ids.key?(template_id) && offered_counts[category_id] > MIN_TEMPLATES_PER_CATEGORY
          offered_counts[category_id] -= 1
          withheld_template_ids << template_id
        end
      end

      withheld_template_ids
    end
end

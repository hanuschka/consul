module DeficiencyReports
  module ManagementReports
    class Figures < ApplicationService
      TOP_LIMIT = 5

      def initialize(profile, period, building_blocks)
        @profile = profile
        @period = period
        @building_blocks = building_blocks
      end

      def call
        @building_blocks.each_with_object({}) do |building_block, figures|
          next unless respond_to?(building_block, true)

          figures[building_block] = send(building_block)
        end
      end

      private

        def reports
          @reports ||= @profile.deficiency_reports
        end

        def incoming
          reports.where(created_at: @period)
        end

        def incoming_and_closed
          {
            "incoming" => incoming.count,
            "closed" => reports.closed.where(status_changed_at: @period).count
          }
        end

        def status_overview
          counts = incoming.group(:deficiency_report_status_id).count

          DeficiencyReport::Status.where(id: counts.keys).map do |status|
            { "name" => status.title, "count" => counts[status.id] }
          end
        end

        def top_categories
          counts = incoming.where.not(deficiency_report_category_id: nil)
                           .group(:deficiency_report_category_id).count
                           .sort_by { |_id, count| -count }
                           .first(TOP_LIMIT)
          names = DeficiencyReport::Category.unscoped.where(id: counts.map(&:first)).index_by(&:id)

          counts.map { |id, count| { "name" => names[id]&.name, "count" => count } }
        end

        def open_and_overdue
          {
            "open" => reports.not_closed.count,
            "overdue" => reports.overdue.count
          }
        end

        def notable_items
          incoming.where("comments_count + cached_votes_up > 0")
                  .reorder(Arel.sql("comments_count + cached_votes_up DESC"), :id)
                  .limit(TOP_LIMIT)
                  .map do |report|
                    {
                      "id" => report.id,
                      "title" => report.title,
                      "comments" => report.comments_count,
                      "supports" => report.cached_votes_up
                    }
                  end
        end
    end
  end
end

module CsvServices
  class BudgetInvestmentsExporter < CsvServices::BaseService
    require "csv"

    COUNT_BATCH_SIZE = 200

    def initialize(budget_investments, host)
      @budget_investments = budget_investments
      @host = host
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        @budget_investments
          .includes(:image)
          .preload(budget: { projekt_phase: [:projekt, :settings] })
          .to_a.each_slice(COUNT_BATCH_SIZE) do |batch|
          @similar_contributions_counts = SimilarContributions::StoredCounts.call(batch)

          batch.each { |budget_investment| csv << row(budget_investment) }
        end
      end
    end

    private

      def headers
        [
          I18n.t("admin.budget_investments.index.list.id"),
          I18n.t("admin.budget_investments.index.list.title"),
          "Beschreibungstext",
          "Katogorien",
          "Sentiment",
          I18n.t("admin.budget_investments.index.list.feasibility"),
          I18n.t("admin.budget_investments.index.list.price"),
          "Folgekosten",
          "Zeitrahmen",
          "Beanstandungskriterium",
          I18n.t("admin.budget_investments.index.list.author_username"),
          "Anzahl Kommentare",
          "Anzahl Votes bei Vorauswahl",
          "Anzahl Votes bei Auswahl",
          "Gebiet",
          "KI-generiertes Bild",
          "URL",
          "Ähnliche Beiträge"
        ]
      end

      def row(investment)
        [
          investment.id,
          sanitize_for_csv(investment.title),
          sanitize_for_csv(strip_tags(investment.description)),
          investment.projekt_labels.map { |pl| pl.name }.join(" | "),
          investment.sentiment&.name,
          I18n.t("admin.budget_investments.index.feasibility.#{investment.feasibility}"),
          investment.formatted_price,
          investment.price_first_year,
          investment.duration,
          investment.valuator_explanation,
          investment.author.username,
          investment.comments_count,
          investment.total_votes.to_s,
          investment.total_ballot_votes.to_s,
          investment.district&.name,
          investment.image&.ai_generated,
          Rails.application.routes.url_helpers.budget_investment_url(investment.budget, investment, host: @host),
          similar_contributions_count(investment)
        ]
      end

      def similar_contributions_count(resource)
        @similar_contributions_counts.fetch(resource.id, 0)
      end

      def admin(investment)
        if investment.administrator.present?
          investment.administrator.name
        else
          I18n.t("admin.budget_investments.index.no_admin_assigned")
        end
      end
  end
end

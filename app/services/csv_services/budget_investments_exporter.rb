module CsvServices
  class BudgetInvestmentsExporter < CsvServices::BaseService
    require "csv"

    def initialize(budget_investments, host)
      @budget_investments = budget_investments
      @host = host
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << headers

        @budget_investments.each do |budget_investment|
          csv << row(budget_investment)
        end
      end
    end

    private

      def headers
        [
          I18n.t("admin.budget_investments.index.list.id"),
          I18n.t("admin.budget_investments.index.list.title"),
          "Beschreibungstext",
          I18n.t("admin.budget_investments.index.list.feasibility"),
          "Beanstandungskriterium",
          I18n.t("admin.budget_investments.index.list.author_username"),
          "Anzahl Kommentare",
          "Anzahl Votes bei Vorauswahl",
          "Anzahl Votes bei Auswahl",
          "URL"
        ]
      end

      def row(investment)
        [
          investment.id,
          sanitize_for_csv(investment.title),
          sanitize_for_csv(strip_tags(investment.description)),
          price(investment),
          investment.valuator_explanation,
          investment.author.username,
          investment.comments_count,
          investment.total_votes.to_s,
          investment.total_ballot_votes.to_s,
          link_to_investment(investment)
        ]
      end

      def admin(investment)
        if investment.administrator.present?
          investment.administrator.name
        else
          I18n.t("admin.budget_investments.index.no_admin_assigned")
        end
      end

      def price(investment)
        price_string = "admin.budget_investments.index.feasibility.#{investment.feasibility}"
        if investment.feasible?
          "#{I18n.t(price_string)} (#{investment.formatted_price})"
        else
          I18n.t(price_string)
        end
      end

      def link_to_investment(investment)
        link = Rails.application.routes.url_helpers.budget_investment_url(investment.budget, investment, host: @host)
        "=HYPERLINK(\"#{link}\", \"#{link}\")"
      end
  end
end

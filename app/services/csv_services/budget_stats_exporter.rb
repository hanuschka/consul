module CsvServices
  class BudgetStatsExporter < CsvServices::BaseService
    include ActionView::Helpers::NumberHelper
    include StatsHelper
    require "csv"

    def initialize(stats)
      @stats = stats
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << [I18n.t("stats.total_participants"), @stats.total_participants]
        add_gender_stats(csv)
        add_age_stats(csv)
        add_geozone_stats(csv)
        add_individual_group_stats(csv)
      end
    end

    private

      def add_gender_stats(csv)
        csv << [""]
        csv << [I18n.t("stats.by_gender")]
        csv << ["Männer", @stats.total_male_participants, number_to_stats_percentage(@stats.male_percentage)]
        csv << ["Frauen", @stats.total_female_participants, number_to_stats_percentage(@stats.female_percentage)]
        csv << ["Dritte", @stats.total_other_gen_participants, number_to_stats_percentage(@stats.other_gen_percentage)]
      end

      def add_age_stats(csv)
        csv << [""]
        csv << [I18n.t("stats.by_age")]
        csv << [I18n.t("stats.age"), I18n.t("stats.total"), I18n.t("stats.percentage")]

        @stats.participants_by_age.values.each do |group|
          csv << [group[:range], group[:count], number_to_stats_percentage(group[:percentage])]
        end
      end

      def add_geozone_stats(csv)
        csv << [""]
        csv << [I18n.t("stats.by_geozone")]
        csv << [I18n.t("stats.geozone"), I18n.t("stats.total"), I18n.t("stats.percentage")]

        @stats.participants_by_geozone.each do |geozone, participants|
          csv << [geozone, participants[:count], number_to_stats_percentage(participants[:percentage])]
        end
      end

      def add_individual_group_stats(csv)
        csv << [""]
        csv << [I18n.t("stats.by_individual_group")]

        @stats.soft_individual_groups.each do |individual_group|
          csv << [individual_group.name, I18n.t("stats.total"), I18n.t("stats.percentage")]
          individual_group.individual_group_values.each do |individual_group_value|
            csv << [
              individual_group_value.name,
              @stats.total_individual_group_value_participants(individual_group_value),
              number_to_stats_percentage(@stats.percentage_individual_group_value_participants(individual_group_value))
            ]
          end
        end
      end
  end
end

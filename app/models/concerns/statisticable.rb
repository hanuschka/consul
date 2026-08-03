module Statisticable
  extend ActiveSupport::Concern
  PARTICIPATIONS = %w[gender age geozone individual_group].freeze

  included do
    attr_reader :resource
  end

  class_methods do
    def stats_methods
      base_stats_methods + gender_methods + age_methods + geozone_methods
    end

    def base_stats_methods
      %i[total_participants participations] + participation_check_methods
    end

    def participation_check_methods
      PARTICIPATIONS.map { |participation| :"#{participation}?" }
    end

    def gender_methods
      %i[
        total_male_participants
        total_female_participants
        total_other_gen_participants
        male_percentage
        female_percentage
        other_gen_percentage
      ]
    end

    def age_methods
      [:participants_by_age]
    end

    def geozone_methods
      %i[participants_by_geozone total_no_demographic_data]
    end

    def stats_cache(*method_names)
      method_names.each do |method_name|
        alias_method :"raw_#{method_name}", method_name

        define_method method_name do
          stats_cache(method_name) { send(:"raw_#{method_name}") }
        end
      end
    end
  end

  def initialize(resource)
    @resource = resource
  end

  def generate
    stats_methods.each { |stat_name| send(stat_name) }
  end

  def stats_methods
    base_stats_methods + participation_methods
  end

  def participations
    PARTICIPATIONS.select { |participation| send("#{participation}?") }
  end

  def gender?
    participants.male.any? || participants.female.any? || participants.other_gen.any?
  end

  def age?
    participants.between_ages(age_groups.flatten.min, age_groups.flatten.max).any?
  end

  def geozone?
    participants.where(geozone: geozones).any?
  end

  def participants
    @participants ||= User.unscoped.where(id: participant_ids)
  end

  def total_male_participants
    participants.male.count
  end

  def total_female_participants
    participants.female.count
  end

  def total_other_gen_participants
    participants.other_gen.count
  end

  def total_no_demographic_data
    participants.where("gender IS NULL OR date_of_birth IS NULL OR geozone_id IS NULL").count
  end

  def male_percentage
    calculate_percentage(total_male_participants, total_participants_with_gender)
  end

  def female_percentage
    calculate_percentage(total_female_participants, total_participants_with_gender)
  end

  def other_gen_percentage
    calculate_percentage(total_other_gen_participants, total_participants_with_gender)
  end

  def participants_by_age
    age_groups.map do |start, finish|
      count = participants.between_ages(start, finish).count

      [
        "#{start} - #{finish}",
        {
          range: range_description(start, finish),
          count: count,
          percentage: calculate_percentage(count, total_participants)
        }
      ]
    end.to_h
  end

  def participants_by_geozone
    geozone_stats.map do |stats|
      [
        stats.name,
        {
          count: stats.count,
          percentage: stats.percentage
        }
      ]
    end.to_h
  end

  def calculate_percentage(fraction, total)
    PercentageCalculator.calculate(fraction, total)
  end

  def version
    "v#{resource.find_or_create_stats_version.updated_at.to_i}"
  end

  def advanced?
    resource.advanced_stats_enabled?
  end

  def show_percentage_values_only?
    false
  end

  def individual_group?
    soft_individual_groups.any?
  end

  def soft_individual_groups
    @soft_individual_groups ||= begin
      IndividualGroup
        .joins(individual_group_values: :users)
        .where(kind: "soft", users: { id: participants.select(:id) })
        .distinct
    end
  end

  def total_individual_group_value_participants(individual_group_value)
    participants.joins(:individual_group_values)
      .where(individual_group_values: { id: individual_group_value.id }).distinct.count
  end

  def total_individual_group_participants(individual_group)
    participants.joins(:individual_group_values)
      .where(individual_group_values: { individual_group_id: individual_group.id }).distinct.count
  end

  def percentage_individual_group_value_participants(individual_group_value)
    total = total_individual_group_participants(individual_group_value.individual_group)
    return 0 if total.zero?

    (total_individual_group_value_participants(individual_group_value).to_f / total) * 100
  end

  def individual_group_breakdown
    groups = soft_individual_groups.includes(:individual_group_values).to_a
    return [] if groups.empty?

    value_counts = participants.joins(:individual_group_values).distinct
      .group("individual_group_values.id").count
    group_counts = participants.joins(:individual_group_values).distinct
      .group("individual_group_values.individual_group_id").count

    groups.map do |group|
      group_total = group_counts[group.id].to_i

      {
        name: group.name,
        values: group.individual_group_values.map do |value|
          count = value_counts[value.id].to_i

          {
            name: value.name,
            count: count,
            percentage: group_total.zero? ? 0 : (count.to_f / group_total * 100)
          }
        end
      }
    end
  end

  private

    def base_stats_methods
      self.class.base_stats_methods
    end

    def not_cached_participations
      %w[individual_group]
    end

    def participation_methods
      cached_participations = participations - not_cached_participations
      cached_participations.map { |participation| self.class.send("#{participation}_methods") }.flatten
    end

    def total_participants_with_gender
      @total_participants_with_gender ||= participants.where.not(gender: nil).distinct.count
    end

    def age_groups
      if @resource.respond_to?(:stats_age_groups) && @resource.stats_age_groups.present?
        return @resource.stats_age_groups
      end

      [[14, 19],
       [20, 24],
       [25, 29],
       [30, 34],
       [35, 39],
       [40, 44],
       [45, 49],
       [50, 54],
       [55, 59],
       [60, 64],
       [65, 69],
       [70, 74],
       [75, 79],
       [80, 84],
       [85, 89],
       [90, 300]
      ]
    end

    def participants_between_ages(from, to)
      participants.between_ages(from, to)
    end

    def geozones
      RegisteredAddress::District.present? ? RegisteredAddress::District.all.order("name") : Geozone.all.order("name")
    end

    def geozone_stats
      geozones.map { |geozone| GeozoneStats.new(geozone, participants) }
    end

    def range_description(start, finish)
      if finish > 200
        I18n.t("stats.age_more_than", start: start)
      else
        I18n.t("stats.age_range", start: start, finish: finish)
      end
    end
end

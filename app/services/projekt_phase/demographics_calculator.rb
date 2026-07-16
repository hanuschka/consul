class ProjektPhase::DemographicsCalculator
  AGE_GROUPS = [
    [16, 19], [20, 24], [25, 29], [30, 34], [35, 39],
    [40, 44], [45, 49], [50, 54], [55, 59], [60, 64],
    [65, 69], [70, 74], [75, 79], [80, 84], [85, 89], [90, 300]
  ].freeze

  def initialize(participant_ids)
    @participant_ids = participant_ids
  end

  def gender_data
    counts = participants.group(:gender).count
    male = counts["male"].to_i
    female = counts["female"].to_i
    other = counts["other_gen"].to_i
    total_with_gender = counts.reject { |gender, _| gender.nil? }.values.sum

    {
      total_male_participants: male,
      total_female_participants: female,
      total_other_gen_participants: other,
      male_percentage: PercentageCalculator.calculate(male, total_with_gender),
      female_percentage: PercentageCalculator.calculate(female, total_with_gender),
      other_gen_percentage: PercentageCalculator.calculate(other, total_with_gender)
    }
  end

  def age_data
    counts = age_bucket_counts

    AGE_GROUPS.map do |from, to|
      count = counts["#{from} - #{to}"].to_i
      [
        "#{from} - #{to}",
        {
          range: range_description(from, to),
          count: count,
          percentage: PercentageCalculator.calculate(count, participants_count)
        }
      ]
    end.to_h
  end

  def geozone_data
    counts = geozone_counts

    geozones.map do |geozone|
      count = counts[geozone.id].to_i
      [
        geozone.name,
        {
          count: count,
          percentage: PercentageCalculator.calculate(count, participants_count)
        }
      ]
    end.to_h
  end

  def individual_group_value_counts
    return {} if @participant_ids.empty?

    UserIndividualGroupValue
      .joins(individual_group_value: :individual_group)
      .where(user_id: @participant_ids, individual_groups: { kind: "soft" })
      .group(:individual_group_value_id)
      .count
  end

  private

    def participants
      @participants ||= User.unscoped.where(id: @participant_ids)
    end

    def participants_count
      @participants_count ||= participants.count
    end

    def age_bucket_counts
      buckets = AGE_GROUPS.map do |from, to|
        "WHEN extract(year from age(date_of_birth)) BETWEEN #{from} AND #{to} THEN '#{from} - #{to}'"
      end

      participants
        .where.not(date_of_birth: nil)
        .group(Arel.sql("CASE #{buckets.join(' ')} END"))
        .count
    end

    def geozone_counts
      if districts_enabled?
        participants.joins(registered_address: :district).group("registered_address_districts.id").count
      else
        participants.group(:geozone_id).count
      end
    end

    def districts_enabled?
      return @districts_enabled if defined?(@districts_enabled)

      @districts_enabled = RegisteredAddress::District.present?
    end

    def range_description(from, to)
      if to > 200
        I18n.t("stats.age_more_than", start: from)
      else
        I18n.t("stats.age_range", start: from, finish: to)
      end
    end

    def geozones
      if districts_enabled?
        RegisteredAddress::District.all.order("name")
      else
        Geozone.all.order("name")
      end
    end
end

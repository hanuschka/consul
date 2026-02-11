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
    participants_with_gender = participants.where.not(gender: nil)
    total_with_gender = participants_with_gender.count

    {
      total_male_participants: participants.male.count,
      total_female_participants: participants.female.count,
      total_other_gen_participants: participants.other_gen.count,
      male_percentage: PercentageCalculator.calculate(participants.male.count, total_with_gender),
      female_percentage: PercentageCalculator.calculate(participants.female.count, total_with_gender),
      other_gen_percentage: PercentageCalculator.calculate(participants.other_gen.count, total_with_gender)
    }
  end

  def age_data
    AGE_GROUPS.map do |from, to|
      count = participants.between_ages(from, to).count
      [
        "#{from} - #{to}",
        {
          range: range_description(from, to),
          count: count,
          percentage: PercentageCalculator.calculate(count, participants.count)
        }
      ]
    end.to_h
  end

  def geozone_data
    geozones.map do |geozone|
      stats = GeozoneStats.new(geozone, participants)
      [
        stats.name,
        {
          count: stats.count,
          percentage: stats.percentage
        }
      ]
    end.to_h
  end

  private

    def participants
      @participants ||= User.unscoped.where(id: @participant_ids)
    end

    def range_description(from, to)
      if to > 200
        I18n.t("stats.age_more_than", start: from)
      else
        I18n.t("stats.age_range", start: from, finish: to)
      end
    end

    def geozones
      if RegisteredAddress::District.present?
        RegisteredAddress::District.all.order("name")
      else
        Geozone.all.order("name")
      end
    end
end

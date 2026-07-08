class ProjektPhase::BudgetPhase::SegmentStats
  def initialize(budget_phase, segment_key)
    @budget_phase = budget_phase
    @segment_key = segment_key
  end

  def total_male_participants
    segment_stat("total_male_participants").to_i
  end

  def total_female_participants
    segment_stat("total_female_participants").to_i
  end

  def total_other_gen_participants
    segment_stat("total_other_gen_participants").to_i
  end

  def participants_by_age
    (segment_stat("participants_by_age") || {}).transform_values(&:with_indifferent_access)
  end

  def participants_by_geozone
    (segment_stat("participants_by_geozone") || {}).transform_values(&:with_indifferent_access)
  end

  def gender?
    total_male_participants > 0 ||
      total_female_participants > 0 ||
      total_other_gen_participants > 0
  end

  def age?
    participants_by_age.values.any? { |value| value[:count].to_i > 0 }
  end

  def geozone?
    participants_by_geozone.values.any? { |value| value[:count].to_i > 0 }
  end

  def individual_group?
    group_value_counts.values.any? { |count| count.to_i > 0 }
  end

  def participations
    [].tap do |result|
      result << "gender" if gender?
      result << "age" if age?
      result << "geozone" if geozone?
    end
  end

  def any_demographics?
    gender? || age? || geozone? || individual_group?
  end

  def soft_individual_groups
    @soft_individual_groups ||= begin
      value_ids = group_value_counts.select { |_, count| count.to_i > 0 }.keys

      if value_ids.blank?
        IndividualGroup.none
      else
        IndividualGroup
          .joins(:individual_group_values)
          .where(kind: "soft", individual_group_values: { id: value_ids })
          .distinct
          .preload(:individual_group_values)
      end
    end
  end

  def total_individual_group_value_participants(individual_group_value)
    group_value_counts.fetch(individual_group_value.id.to_s, 0).to_i
  end

  private

    def segment_stat(suffix)
      @budget_phase.stats["#{@segment_key}_#{suffix}"]
    end

    def group_value_counts
      segment_stat("individual_group_value_counts") || {}
    end
end

require_dependency Rails.root.join("app", "models", "concerns", "statisticable").to_s

module Statisticable
  PARTICIPATIONS = %w[gender age geozone individual_group].freeze

  class_methods do
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
  end

  def gender?
    participants.male.any? || participants.female.any? || participants.other_gen.any?
  end

  def other_gen_percentage
    calculate_percentage(total_other_gen_participants, total_participants_with_gender)
  end

  def total_other_gen_participants
    participants.other_gen.count
  end

  def show_percentage_values_only?
    false
  end

  def individual_group?
    soft_individual_groups.any?
  end

  def soft_individual_groups
    @soft_individual_groups ||= IndividualGroup.joins(individual_group_values: :users)
      .where(kind: "soft", users: { id: participants.ids }).distinct
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
    total_individual_group_value_participants(individual_group_value) /
      total_individual_group_participants(individual_group_value.individual_group).to_f * 100
  end

  private

    def participation_methods
      cached_participations = participations - not_cached_participations
      cached_participations.map { |participation| self.class.send("#{participation}_methods") }.flatten
    end

    def not_cached_participations
      %w[individual_group]
    end
end

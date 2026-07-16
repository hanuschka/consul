class ProjektPhase::CommentPhase < ProjektPhase
  store_accessor :stats,
    :total_male_participants,
    :total_female_participants,
    :total_other_gen_participants,
    :male_percentage,
    :female_percentage,
    :other_gen_percentage,
    :individual_group_value_counts

  def gender?
    total_male_participants.to_i > 0 ||
      total_female_participants.to_i > 0 ||
      total_other_gen_participants.to_i > 0
  end

  def age?
    participants_by_age.values.any? { |v| v[:count].to_i > 0 }
  end

  def geozone?
    participants_by_geozone.values.any? { |v| v[:count].to_i > 0 }
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

  def participants_by_age
    (stats["participants_by_age"] || {}).transform_values(&:with_indifferent_access)
  end

  def participants_by_geozone
    (stats["participants_by_geozone"] || {}).transform_values(&:with_indifferent_access)
  end

  def name
    "comment_phase"
  end

  def sidebar_cta_kind
    :link
  end

  def sidebar_cta_anchor
    "new_comments_component"
  end

  def resources_name
    "comments"
  end

  def default_order
    1
  end

  def resource_count
    comments.count
  end

  def customizable_email_templates
    [
      ["NotificationServiceMailer", "new_comment"]
    ]
  end

  def admin_nav_bar_items
    %w[duration naming restrictions comments email_templates]
  end

  def safe_to_destroy?
    comments.empty?
  end

  def comments_allowed?(current_user)
    selectable_by?(current_user)
  end

  private

    def group_value_counts
      individual_group_value_counts || {}
    end

    def phase_specific_permission_problems(user, location)
      nil
    end
end

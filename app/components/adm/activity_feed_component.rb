class Adm::ActivityFeedComponent < ApplicationComponent
  delegate :time_ago_in_words, to: :helpers

  attr_reader :activities

  def initialize(activities:)
    @activities = activities
  end

  def render?
    activities.any?
  end

  def activity_description(activity)
    user_name = activity.user&.name || t(".activity_unknown_user")
    trackable_name = activity.metadata&.dig("trackable_name") || activity.trackable_type&.demodulize || "—"
    action_label = t(".activity_action_#{activity.action}", default: activity.action)
    changed_fields = activity.metadata&.dig("changed_fields")
    detail = if changed_fields.present?
               " (#{changed_fields.map { |f| human_attribute_for(activity, f) }.join(', ')})"
             else
               ""
             end
    "#{user_name} #{t('.activity_has')} #{trackable_name} #{action_label}#{detail}"
  end

  def human_attribute_for(activity, field)
    klass = activity.trackable_type&.safe_constantize
    klass ? klass.human_attribute_name(field) : field.humanize
  end

  def activity_time(activity)
    time_ago_in_words(activity.created_at)
  end
end

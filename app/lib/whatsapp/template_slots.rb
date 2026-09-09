module Whatsapp::TemplateSlots
  # Every place a template name can be stored, in the order the templates tab
  # shows them: the two broadcast slots first, then the pushes in catalog order.
  #
  # Derived from the two SETTING_KEYS_BY_KIND maps rather than listed here. A
  # hand-written slot list would answer "what is active" for whatever it happened
  # to name on the day it was written, and a kind added to either catalog would
  # silently stop being reported.
  BROADCAST_GROUP = :broadcast
  NOTIFICATION_GROUP = :notification

  module_function

  # One uniform row per slot, whatever its group: the tab renders them all with
  # the same markup, so it must not have to know which of the two catalogs a row
  # came from to read its name, status or action.
  def all(listed_templates)
    broadcast(listed_templates) + notification(listed_templates)
  end

  def broadcast(listed_templates)
    language = ::Whatsapp.broadcast_template_language

    ::Whatsapp::BroadcastTemplates::SETTING_KEYS_BY_KIND.keys.map do |kind|
      broadcast_slot(kind, listed_templates, language)
    end
  end

  # The push states are already assembled by the catalog that owns them, so this
  # only re-shapes them into the row the tab renders.
  def notification(listed_templates)
    ::Whatsapp::NotificationTemplates.states(listed_templates).map do |state|
      notification_slot(state)
    end
  end

  def broadcast_slot(kind, listed_templates, language)
    configured_name = ::Whatsapp::BroadcastTemplates.name_for(kind)

    listed = listed_templates.find do |template|
      template[:name] == configured_name && template[:language] == language
    end

    # A name stored with no matching template is its own state: the setting the
    # broadcast job reads points at something 360dialog does not have, which the
    # page has to say rather than showing an empty status.
    #
    # An empty setting is a third state again, and `missing_status` is what tells
    # the three apart. A broadcast slot has no status of its own to report while
    # nothing is stored in it — there is no template for Meta to have an opinion
    # about — whereas an unsubmitted push does have one, because its name is
    # fixed by the kind.
    {
      group: BROADCAST_GROUP,
      kind: kind,
      label: I18n.t("adm.whatsapp.show.template_kind_#{kind}"),
      name: configured_name,
      language: configured_name.present? ? language : nil,
      status: listed&.fetch(:status),
      missing_status: configured_name.present? ? nil : :not_configured,
      approved: listed.present? && listed[:approved],
      submitted: listed.present?,
      configured: configured_name.present?,
      body: nil,
      button: nil
    }
  end

  # The push row names the template it would submit even while nothing is armed,
  # because that name is fixed by the kind — unlike a broadcast slot, where an
  # empty setting means there is no name to show yet.
  def notification_slot(state)
    {
      group: NOTIFICATION_GROUP,
      kind: state[:kind],
      label: I18n.t("adm.whatsapp.show.notification_template_kinds.#{state[:kind]}"),
      name: state[:configured_name] || state[:name],
      language: state[:language],
      status: state[:status],
      missing_status: state[:submitted] ? nil : :not_submitted,
      approved: state[:approved],
      submitted: state[:submitted],
      configured: state[:configured_name].present?,
      body: state[:body],
      button: state[:button]
    }
  end

  # What the summary counts as answered. A slot is only settled once a name is
  # stored AND the listing reports that name approved: an armed slot pointing at
  # a pending or withdrawn template sends nothing.
  def armed?(slot)
    slot[:configured] && slot[:approved]
  end

  def armed_count(slots)
    slots.count { |slot| armed?(slot) }
  end

  private_class_method :broadcast_slot, :notification_slot
end

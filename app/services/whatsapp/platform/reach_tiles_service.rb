class Whatsapp::Platform::ReachTilesService < ApplicationService
  # Above this share of linked accounts, opt-outs stop being noise and become
  # something worth acting on.
  OPT_OUT_SHARE_THRESHOLD = 0.1

  TONE_DANGER = "danger".freeze
  TONE_SUCCESS = "success".freeze

  def initialize(stats)
    @accounts = stats[:accounts]
    @activity = stats[:activity]
    @messages = stats[:messages]
    @conversations = stats[:conversations]
  end

  def call
    {
      contacts: { tiles: contact_tiles, breakdown: contact_breakdown },
      activity: { tiles: activity_tiles, breakdown: [] },
      messages: { tiles: message_tiles, breakdown: message_breakdown },
      flows: { tiles: flow_tiles, breakdown: [] }
    }
  end

  private

    attr_reader :accounts, :activity, :messages, :conversations

    def contact_tiles
      [
        tile(:total, accounts[:total]),
        tile(:linked, accounts[:linked]),
        tile(:subscribed, accounts[:subscribed], tone: subscribed_tone),
        tile(:opted_out, accounts[:opted_out], tone: opt_out_tone)
      ]
    end

    def activity_tiles
      [
        tile(:active_recent, activity[:active_recent], tone: active_recent_tone),
        tile(:active_growth, activity[:active_growth]),
        tile(:new_verified, activity[:new_verified], tone: stagnation_tone(activity[:new_verified])),
        tile(:new_opt_ins, activity[:new_opt_ins], tone: stagnation_tone(activity[:new_opt_ins]))
      ]
    end

    def message_tiles
      [
        tile(:inbound, messages[:inbound], hint: recent_hint(messages[:recent_inbound])),
        tile(:outbound, messages[:outbound], hint: recent_hint(messages[:recent_outbound])),
        tile(:failed_outbound, messages[:failed_outbound], tone: failed_outbound_tone)
      ]
    end

    def flow_tiles
      conversations[:by_step].map do |step, count|
        { value: count, label: I18n.t("adm.whatsapp.steps.#{step}"), hint: nil, tone: nil }
      end
    end

    def contact_breakdown
      %i[verified link_pending unlinked].map do |key|
        { label: label(key), value: accounts[key] }
      end
    end

    def message_breakdown
      return [] if messages[:inbound].zero? && messages[:outbound].zero?

      messages[:by_kind].map do |kind, count|
        { label: I18n.t("adm.whatsapp.kinds.#{kind}"), value: count }
      end
    end

    # A zero that is the best possible outcome has to look like one, so failures
    # only read as confirmed good once something has actually been sent.
    def failed_outbound_tone
      return TONE_DANGER if messages[:failed_outbound].positive?
      return TONE_SUCCESS if messages[:outbound].positive?

      nil
    end

    def subscribed_tone
      TONE_SUCCESS if accounts[:subscribed].positive?
    end

    # Raw opt-out counts grow with the audience, so the share is what decides
    # whether the number needs attention.
    def opt_out_tone
      return nil if accounts[:linked].zero?

      share = accounts[:opted_out].to_f / accounts[:linked]

      TONE_DANGER if share > OPT_OUT_SHARE_THRESHOLD
    end

    def active_recent_tone
      activity[:active_recent].positive? ? TONE_SUCCESS : TONE_DANGER
    end

    def stagnation_tone(value)
      TONE_DANGER if value.zero?
    end

    def recent_hint(count)
      I18n.t("adm.whatsapp.reach.last_30_days", count: delimited(count))
    end

    def tile(key, value, tone: nil, hint: nil)
      { value: value, label: label(key), hint: hint, tone: tone }
    end

    def label(key)
      I18n.t("adm.whatsapp.reach.#{key}")
    end

    def delimited(count)
      ActiveSupport::NumberHelper.number_to_delimited(count)
    end
end

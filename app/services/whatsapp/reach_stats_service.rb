class Whatsapp::ReachStatsService < ApplicationService
  RECENT_WINDOW = 7.days
  GROWTH_WINDOW = 30.days
  BROADCAST_PROJEKT_LIMIT = 20

  def call
    {
      accounts: account_stats,
      activity: activity_stats,
      messages: message_stats,
      broadcasts: broadcast_rows,
      conversations: conversation_stats
    }
  end

  private

    def account_stats
      counts_by_state = WhatsappAccount.group(:state).count

      {
        total: counts_by_state.values.sum,
        unlinked: counts_by_state["unlinked"].to_i,
        link_pending: counts_by_state["link_pending"].to_i,
        linked: counts_by_state["linked"].to_i,
        verified: WhatsappAccount.verified.count,
        subscribed: WhatsappAccount.subscribed.count,
        opted_out: WhatsappAccount.where.not(opt_out_at: nil).count
      }
    end

    def activity_stats
      {
        active_recent: WhatsappAccount.where(last_inbound_at: RECENT_WINDOW.ago..).count,
        active_growth: WhatsappAccount.where(last_inbound_at: GROWTH_WINDOW.ago..).count,
        new_verified: WhatsappAccount.where(verified_at: GROWTH_WINDOW.ago..).count,
        new_opt_ins: WhatsappAccount.where(opt_in_at: GROWTH_WINDOW.ago..).count
      }
    end

    def message_stats
      by_direction = WhatsappMessage.group(:direction).count
      recent_by_direction =
        WhatsappMessage.where(created_at: GROWTH_WINDOW.ago..).group(:direction).count

      {
        inbound: by_direction["inbound"].to_i,
        outbound: by_direction["outbound"].to_i,
        recent_inbound: recent_by_direction["inbound"].to_i,
        recent_outbound: recent_by_direction["outbound"].to_i,
        failed_outbound: failed_outbound_count,
        by_kind: counts_by_kind
      }
    end

    def counts_by_kind
      counts = WhatsappMessage.group(:kind).count

      WhatsappMessage.kinds.each_key.index_with { |kind| counts[kind].to_i }
    end

    def failed_outbound_count
      WhatsappMessage.where(direction: "outbound", status: "failed").count
    end

    def broadcast_rows
      counts = broadcast_scope.group(:projekt_id, :status).count
      return [] if counts.empty?

      last_sent_at = broadcast_scope.group(:projekt_id).maximum(:created_at)
      names = broadcast_projekt_names(last_sent_at.keys)

      rows = last_sent_at.map do |projekt_id, sent_at|
        {
          projekt_id: projekt_id,
          projekt_name: names[projekt_id],
          sent: counts[[projekt_id, "sent"]].to_i,
          failed: counts[[projekt_id, "failed"]].to_i,
          last_sent_at: sent_at
        }
      end

      rows.sort_by { |row| -row[:last_sent_at].to_i }.first(BROADCAST_PROJEKT_LIMIT)
    end

    def broadcast_scope
      WhatsappMessage
        .where(kind: "template", direction: "outbound")
        .where.not(projekt_id: nil)
    end

    def broadcast_projekt_names(projekt_ids)
      Projekt
        .where(id: projekt_ids)
        .includes(:page)
        .each_with_object({}) do |projekt, names|
          names[projekt.id] = Whatsapp::ProjektLink.title(projekt)
        end
    end

    def conversation_stats
      by_step = WhatsappConversation.group(:step).count

      {
        total: by_step.values.sum,
        in_flight: by_step.except("idle").values.sum,
        by_step: by_step.except("idle")
      }
    end
end

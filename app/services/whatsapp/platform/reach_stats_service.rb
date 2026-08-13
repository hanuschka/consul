class Whatsapp::Platform::ReachStatsService < ApplicationService
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
      counts_by_state = Whatsapp::Account.group(:state).count

      {
        total: counts_by_state.values.sum,
        unlinked: counts_by_state["unlinked"].to_i,
        link_pending: counts_by_state["link_pending"].to_i,
        linked: counts_by_state["linked"].to_i,
        verified: Whatsapp::Account.verified.count,
        subscribed: Whatsapp::Account.subscribed.count,
        opted_out: Whatsapp::Account.where.not(opt_out_at: nil).count
      }
    end

    def activity_stats
      {
        active_recent: Whatsapp::Account.where(last_inbound_at: RECENT_WINDOW.ago..).count,
        active_growth: Whatsapp::Account.where(last_inbound_at: GROWTH_WINDOW.ago..).count,
        new_verified: Whatsapp::Account.where(verified_at: GROWTH_WINDOW.ago..).count,
        new_opt_ins: Whatsapp::Account.where(opt_in_at: GROWTH_WINDOW.ago..).count
      }
    end

    def message_stats
      by_direction = Whatsapp::Message.group(:direction).count
      recent_by_direction =
        Whatsapp::Message.where(created_at: GROWTH_WINDOW.ago..).group(:direction).count

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
      counts = Whatsapp::Message.group(:kind).count

      Whatsapp::Message.kinds.each_key.index_with { |kind| counts[kind].to_i }
    end

    def failed_outbound_count
      Whatsapp::Message.where(direction: "outbound", status: "failed").count
    end

    # One grouped pass over the broadcast rows rather than a count and a maximum
    # over the same scan: whatsapp_messages is the largest table the feature has
    # and this renders on every /adm/whatsapp load.
    #
    # "sent" is everything that left the system, not literally status "sent": a
    # delivery receipt moves a row on to "delivered" and then "read", so
    # counting the one status reported zero for every broadcast whose receipts
    # had come back. Whatsapp::Message.broadcast_delivered? draws the same line.
    def broadcast_rows
      totals_by_projekt = broadcast_totals_by_projekt

      return [] if totals_by_projekt.empty?

      names = broadcast_projekt_names(totals_by_projekt.keys)

      rows = totals_by_projekt.map do |projekt_id, totals|
        {
          projekt_id: projekt_id,
          projekt_name: names[projekt_id],
          sent: totals[:sent],
          failed: totals[:failed],
          last_sent_at: totals[:last_sent_at]
        }
      end

      rows.sort_by { |row| -row[:last_sent_at].to_i }.first(BROADCAST_PROJEKT_LIMIT)
    end

    def broadcast_totals_by_projekt
      grouped = broadcast_scope
        .group(:projekt_id, :status)
        .pluck(:projekt_id, :status, Arel.sql("COUNT(*)"), Arel.sql("MAX(created_at)"))

      grouped.each_with_object({}) do |(projekt_id, status, count, last_created_at), totals|
        row = totals[projekt_id] ||= { sent: 0, failed: 0, last_sent_at: nil }
        bucket = status == "failed" ? :failed : :sent

        row[bucket] += count
        row[:last_sent_at] = [row[:last_sent_at], last_created_at].compact.max
      end
    end

    def broadcast_scope
      Whatsapp::Message
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
      by_step = Whatsapp::Conversation.group(:step).count
      in_flight = by_step.except(Whatsapp::Conversation::Step::IDLE)

      {
        total: by_step.values.sum,
        in_flight: in_flight.values.sum,
        by_step: in_flight
      }
    end
end

module Whatsapp::WorkerHeartbeat
  module_function

  # Which credentials every running Delayed Job worker booted with. Secrets are
  # read once per process, so editing them and restarting only Puma leaves a
  # worker that accepts each job and cannot send what it is asked to; the admin
  # page compares the fingerprints reported here with its own.
  #
  # One entry per worker in a single key, because memcache cannot list keys. Two
  # workers beating at the same moment can drop one entry until its next beat,
  # which can only ever hide a stale worker for a minute, never invent one.
  CACHE_KEY = "whatsapp/worker_heartbeats".freeze
  INTERVAL = 1.minute

  # A worker beats between jobs, so one busy with a long job (an evaluation, a
  # PDF) falls silent for that long. Its entry expiring hides it from the
  # comparison rather than reporting it stale.
  EXPIRY = 15.minutes

  # Every call outside the boot beat is throttled to one write per INTERVAL:
  # the loop callback runs every Delayed::Worker.sleep_delay seconds.
  def beat(worker_name)
    return if @last_beat_at.present? && @last_beat_at > INTERVAL.ago

    beat_now(worker_name)
  end

  def beat_now(worker_name)
    @last_beat_at = Time.current

    write(
      live_entries.merge(
        worker_name => { fingerprint: ::Whatsapp.credentials_fingerprint, beat_at: @last_beat_at }
      )
    )
  end

  # On a clean stop, so the restart that fixes a stale worker clears the alert
  # at once instead of after EXPIRY.
  def forget(worker_name)
    write(live_entries.except(worker_name))
  end

  def outdated?
    fingerprint = ::Whatsapp.credentials_fingerprint

    live_entries.values.any? { |entry| entry[:fingerprint] != fingerprint }
  end

  def live_entries
    entries = Rails.cache.read(CACHE_KEY)

    return {} if !entries.is_a?(Hash)

    entries.select { |_worker_name, entry| entry[:beat_at] > EXPIRY.ago }
  end

  def write(entries)
    Rails.cache.write(CACHE_KEY, entries, expires_in: EXPIRY)
  end
end

Rails.application.config.after_initialize do
  Whatsapp.report_webhook_authentication
end

# Reports the credentials each Delayed Job worker booted with, for the
# stale-worker alert on the admin WhatsApp pages (Whatsapp::WorkerHeartbeat).
# Beats on start, between polls and before each job; forgets the worker on a
# clean stop, which is what a restart does.
class WhatsappWorkerHeartbeatPlugin < Delayed::Plugin
  callbacks do |lifecycle|
    lifecycle.around(:execute) do |worker, &block|
      Whatsapp::WorkerHeartbeat.beat_now(worker.name)
      block.call(worker)
    ensure
      Whatsapp::WorkerHeartbeat.forget(worker.name)
    end

    lifecycle.before(:loop) { |worker| Whatsapp::WorkerHeartbeat.beat(worker.name) }
    lifecycle.before(:perform) { |worker, _job| Whatsapp::WorkerHeartbeat.beat(worker.name) }
  end
end

Delayed::Worker.plugins << WhatsappWorkerHeartbeatPlugin

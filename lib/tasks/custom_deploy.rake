namespace :custom_deploy do
  desc "Launches delay job service"
  task launch_delay_job: :environment do
    ApplicationLogger.new.info "Launching delay job service"
    sudo systemctl status delayed_job2
  end
end

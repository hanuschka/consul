# config valid only for current version of Capistrano
lock "~> 3.17.3"

require "base64"
require "json"
require "open3"

OP_ACCOUNT = "demokratietoday.1password.eu".freeze
DEMO_DEPLOY_ITEM = "cli_demo_2 prod".freeze
HOSTS_ITEM_ENVS = { "production" => "prod", "staging" => "stage" }.freeze

def deploysecret(key)
  deploy_target.fetch(key.to_s, "undefined")
end

def deploy_branch
  @deploy_branch ||= begin
    branch = ENV["branch"].to_s.strip
    abort "branch=<branch> is required, e.g. branch=cli_demo_2 cap #{fetch(:stage)} deploy" if branch.empty?

    current_branch = `git rev-parse --abbrev-ref HEAD`.strip
    abort "branch=#{branch} does not match the checked-out branch #{current_branch}" if branch != current_branch

    branch
  end
end

def deploy_target
  @deploy_target ||= begin
    deploy_branch
    op_installed? ? deploy_target_from_hosts_vault : deploy_target_from_local_file
  end
end

def op_installed?
  !system("op", "--version", out: File::NULL, err: File::NULL).nil?
end

def deploy_target_from_hosts_vault
  env = HOSTS_ITEM_ENVS[fetch(:stage).to_s]
  abort "No hosts vault mapping for stage #{fetch(:stage)}" unless env

  title = "#{deploy_branch} #{env}"
  item = hosts_vault_item(title)

  if item.nil?
    abort "No hosts vault item #{title.inspect}; feature branches deploy only to production (#{DEMO_DEPLOY_ITEM})" if env != "prod"

    title = DEMO_DEPLOY_ITEM
    item = hosts_vault_item(title) || abort("No hosts vault item #{title.inspect}")
  end

  fields = item.fetch("fields", []).to_h { |field| [field["label"], field["value"].to_s] }.reject { |_, value| value.empty? }
  abort "Hosts vault item #{title.inspect} has no ip" unless fields["ip"]

  puts "Deploy target: #{deploy_branch} -> #{title} (#{fields["ip"]})"

  {
    "server" => fields["ip"],
    "server1" => fields["ip"],
    "user" => fields.fetch("deploy_user", "deploy"),
    "ssh_port" => fields.fetch("ssh_port", "22"),
    "deploy_to" => fields.fetch("deploy_to", "/home/deploy/consul")
  }
end

def hosts_vault_item(title)
  output, error, status = Open3.capture3("op", "item", "get", title, "--vault", "hosts", "--account", OP_ACCOUNT, "--format", "json")
  return JSON.parse(output) if status.success?
  return nil if error.include?("isn't an item")

  abort "1Password lookup of #{title.inspect} failed: #{error.strip}"
end

def deploy_target_from_local_file
  path = "config/deploy-secrets/deploy-secrets-#{deploy_branch.delete_suffix("_2")}.yml"
  abort "1Password CLI not found and no #{path}" unless File.exist?(path)

  YAML.load_file(path)[fetch(:stage).to_s] || abort("#{path} has no #{fetch(:stage)} entry")
end

set :rails_env, fetch(:stage)
set :rvm1_map_bins, -> { fetch(:rvm_map_bins).to_a.concat(%w[rake gem bundle ruby]).uniq }

set :application, "consul"
set :deploy_to, deploysecret(:deploy_to)
set :ssh_options, {
  port: deploysecret(:ssh_port),
  # Use this for debug ssh connection
  # verbose: :debug # or :info, :error
}

set :repo_url, "https://github.com/hanuschka/consul.git"

set :revision, `git rev-parse --short #{fetch(:branch)}`.strip

set :log_level, :info
set :pty, true
set :use_sudo, false

set :linked_files, %w[config/database.yml config/secrets.yml config/secret_emails.yml]
set :linked_dirs, %w[.bundle log node_modules tmp public/system public/assets public/ckeditor_assets public/machine_learning/data storage]

set :keep_releases, 5

set :local_user, ENV["USER"]

set :fnm_path, "$HOME/.fnm"
set :fnm_install_command, "curl -fsSL https://fnm.vercel.app/install | " \
                          "bash -s -- --install-dir \"#{fetch(:fnm_path)}\""
set :fnm_update_command, "#{fetch(:fnm_install_command)} --skip-shell"
set :fnm_setup_command, -> do
                          "export PATH=\"#{fetch(:fnm_path)}:$PATH\" && " \
                            "cd #{release_path} && fnm env > /dev/null && eval \"$(fnm env)\""
                        end
set :fnm_install_node_command, -> { "#{fetch(:fnm_setup_command)} && fnm use --install-if-missing" }
set :fnm_map_bins, %w[bundle node npm puma pumactl rake yarn]

set :puma_conf, "#{release_path}/config/puma/#{fetch(:rails_env)}.rb"
set :puma_systemctl_user, :user
# Puma owns its socket via the `bind` directive in config/puma/defaults.rb;
# don't let capistrano-puma also generate a systemd .socket unit, otherwise
# the two race to bind the same path and puma crashes on boot.
set :puma_enable_socket_service, false
# capistrano3-puma 8 renamed the unit and moved its access log. Keep the old
# names: per-host drop-ins (jemalloc, OOMPolicy) live under the unit's name.
# The unit itself comes from config/deploy/templates/puma.service.erb.
set :puma_service_unit_name, -> { "puma_#{fetch(:application)}_#{fetch(:stage)}" }
set :puma_access_log, -> { File.join(shared_path, "log", "puma_access.log") }

set :delayed_job_workers, 2
set :delayed_job_roles, :background

set :whenever_roles, -> { :app }

namespace :deploy do
  before :starting, :record_deploy_start_time do
    set :deploy_started_at, Time.now
  end

  after "rvm1:hook", "map_node_bins"

  after :updating, "install_node"
  after :updating, "install_ruby"

  after "deploy:migrate", "add_new_settings"

  after :publishing, "setup_puma"
  after :finished, "restart_delayed_jobs"
  after :finished, "refresh_sitemap"

  desc "Deploys and runs the tasks needed to upgrade to a new release"
  task :upgrade do
    after "add_new_settings", "execute_release_tasks"
    invoke "deploy"
  end

  before "deploy:restart", "puma:restart"
end

task :install_ruby do
  on roles(:app) do
    within release_path do
      begin
        current_ruby = capture(:rvm, "current")
      rescue SSHKit::Command::Failed
        after "install_ruby", "rvm1:install:rvm"
        after "install_ruby", "rvm1:install:ruby"
      else
        if current_ruby.include?("not installed")
          after "install_ruby", "rvm1:install:rvm"
          after "install_ruby", "rvm1:install:ruby"
        else
          info "Ruby: Using #{current_ruby}"
        end
      end
    end
  end
end

task :install_node do
  on roles(:app) do
    with rails_env: fetch(:rails_env) do
      begin
        execute fetch(:fnm_install_node_command)
      rescue SSHKit::Command::Failed
        begin
          execute fetch(:fnm_setup_command)
        rescue SSHKit::Command::Failed
          execute fetch(:fnm_install_command)
        else
          execute fetch(:fnm_update_command)
        end

        execute fetch(:fnm_install_node_command)
      end
    end
  end
end

task :map_node_bins do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        prefix = -> { "#{fetch(:fnm_path)}/fnm exec" }

        fetch(:fnm_map_bins).each do |command|
          SSHKit.config.command_map.prefix[command.to_sym].unshift(prefix)
        end
      end
    end
  end
end

task :refresh_sitemap do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "sitemap:refresh:no_ping"
      end
    end
  end
end

task :add_new_settings do
  on roles(:db) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "settings:add_new_settings"
        execute :rake, "settings:destroy_obsolete"
        execute :rake, "projekt_settings:ensure_existence"
        execute :rake, "projekt_settings:destroy_obsolete"
        execute :rake, "projekt_phase_settings:add_new_settings"
        execute :rake, "projekt_phase_settings:destroy_obsolete"
        execute :rake, "deficiency_report_statuses:add_default_statuses"
      end
    end
  end
end

# Installs exiftool, which a client needs to generate AI images. Marking
# generated images is mandatory, so on a client with AI enabled every
# generation fails until this has run once.
#
# Deliberately not hooked into deploy: a client without AI has no use for it.
# Run it per client instead, once:
#
#   branch=<client-branch> bundle exec cap production install_ai_marking
task :install_ai_marking do
  on roles(:app) do
    within release_path do
      execute :bash, "#{release_path}/scripts/install_deps.sh", "marking"
    end
  end
end

# Reports the same dependency checks the internal API stats endpoint exposes,
# without installing anything. Useful for answering "is this box ready" across
# several clients before or after a release.
task :check_deps do
  on roles(:app) do
    within release_path do
      execute :bash, "#{release_path}/scripts/install_deps.sh", "verify"
    end
  end
end

task :execute_release_tasks do
  on roles(:app) do
    within release_path do
      with rails_env: fetch(:rails_env) do
        execute :rake, "consul:execute_release_tasks"
      end
    end
  end
end

task :restart_delayed_jobs do
  on roles(:app) do
    template_unit_present = test("[ -f /etc/systemd/system/delayed_job@.service ]")
    within release_path do
      with rails_env: fetch(:rails_env) do
        if template_unit_present
          fetch(:delayed_job_workers).times do |i|
            execute "sudo systemctl restart delayed_job@#{i + 1}"
          end
        else
          # Legacy cli_* branches: only the literal delayed_job2 unit exists.
          execute "sudo systemctl restart delayed_job2"
        end
      end
    end
  end
end

desc "Create pid and socket folders needed by puma"
task :setup_puma do
  on roles(fetch(:puma_role)) do
    with rails_env: fetch(:rails_env) do
      execute "mkdir -p #{shared_path}/tmp/sockets; true"
      execute "mkdir -p #{shared_path}/tmp/pids; true"
    end
  end

  after "setup_puma", "puma:install"
end

# Print total wall-clock deploy time as the final line. Registered after the
# other deploy:finished hooks (restart_delayed_jobs, refresh_sitemap) so it
# runs last.
task :report_deploy_duration do
  started_at = fetch(:deploy_started_at)
  next unless started_at

  elapsed = (Time.now - started_at).round
  minutes, seconds = elapsed.divmod(60)
  formatted = minutes.positive? ? "#{minutes}m #{seconds}s" : "#{seconds}s"

  run_locally do
    info "Deploy to #{fetch(:stage)} finished in #{formatted} (#{elapsed}s total)"
  end
end

after "deploy:finished", "report_deploy_duration"

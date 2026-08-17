require "uri"

branch = ENV["branch"]

if branch.nil? || branch.empty?
  branch = `git rev-parse --abbrev-ref HEAD`.strip
end

set :branch, branch

deploy_staging_domain = ENV["DEPLOY_STAGING_DOMAIN"]

staging_server =
  if deploy_staging_domain.nil? || deploy_staging_domain.empty?
    deploysecret(:server)
  else
    URI(deploy_staging_domain).host || deploy_staging_domain
  end

server staging_server, user: deploysecret(:user), roles: %w[web app db importer cron background]

set :default_env, {
  "XDG_RUNTIME_DIR" => "/run/user/1001",
  "DBUS_SESSION_BUS_ADDRESS" => "unix:path=/run/user/1001/bus"
}

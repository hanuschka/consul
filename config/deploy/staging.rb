require "uri"

branch = ENV["branch"]

if branch.nil? || branch.empty?
  branch = `git rev-parse --abbrev-ref HEAD`.strip
end

set :branch, branch

deploy_staging_url = ENV["DEPLOY_STAGING_URL"]

staging_server =
  if deploy_staging_url.nil? || deploy_staging_url.empty?
    deploysecret(:server)
  else
    URI(deploy_staging_url).host || deploy_staging_url
  end

server staging_server, user: deploysecret(:user), roles: %w[web app db importer cron background]

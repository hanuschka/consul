class Admin::AppMetadataService < ApplicationService
  def call
    {
      git_sha:        read_git_sha,
      git_sha_short:  read_git_sha&.first(7),
      last_deploy_at: read_last_deploy_at&.iso8601,
      rails_env:      Rails.env,
      ruby_version:   RUBY_VERSION,
      rails_version:  Rails.version,
      hostname:       read_hostname,
      uptime_seconds: read_uptime_seconds,
      app_started_at: app_started_at&.iso8601
    }
  end

  private

  def read_git_sha
    revision_path = Rails.root.join("REVISION")

    if File.exist?(revision_path)
      return File.read(revision_path).strip
    end

    sha = `timeout 2 git rev-parse HEAD 2>/dev/null`.strip
    sha.presence
  rescue StandardError
    nil
  end

  def read_last_deploy_at
    revision_path = Rails.root.join("REVISION")

    if File.exist?(revision_path)
      return File.mtime(revision_path)
    end

    release_dir = release_dir_from_root

    if release_dir
      return File.mtime(release_dir)
    end

    nil
  rescue StandardError
    nil
  end

  def release_dir_from_root
    root = Rails.root.to_s

    return nil if !root.include?("/releases/")

    root
  end

  def read_hostname
    Socket.gethostname
  rescue StandardError
    nil
  end

  def read_uptime_seconds
    File.read("/proc/uptime").split.first.to_f.round
  rescue StandardError
    nil
  end

  def app_started_at
    return @app_started_at if defined?(@app_started_at)

    @app_started_at =
      if Rails.application.config.respond_to?(:booted_at)
        Rails.application.config.booted_at
      else
        nil
      end
  end
end

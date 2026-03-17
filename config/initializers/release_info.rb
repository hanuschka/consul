begin
  revision_file = Rails.root.join("REVISION")
  if revision_file.exist?
    RELEASE_DATE = File.mtime(revision_file).to_date
  else
    git_date_str = `git log -1 --format=%ai 2>/dev/null`.strip
    RELEASE_DATE = git_date_str.present? ? Date.parse(git_date_str) : nil
  end
rescue
  RELEASE_DATE = nil
end

begin
  git_tag = `git describe --tags --abbrev=0 2>/dev/null`.strip
  git_date_str = `git log -1 --format=%ai "#{git_tag}" 2>/dev/null`.strip
  RELEASE_TAG = git_tag.presence
  RELEASE_DATE = git_date_str.present? ? Date.parse(git_date_str) : nil
rescue
  RELEASE_TAG = nil
  RELEASE_DATE = nil
end

begin
  git_date_str = `git log -1 --format=%ai 2>/dev/null`.strip
  RELEASE_DATE = git_date_str.present? ? Date.parse(git_date_str) : nil
rescue
  RELEASE_DATE = nil
end

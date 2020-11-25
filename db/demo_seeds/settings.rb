section "Creating DEMO Settings" do
  {
    "org_name": "CONSUL DEMO",
    "url": "https://demo.consulproject.org",
    "meta_description": "Citizen participation tool for an open, transparent and democratic government",
    "meta_keywords": "citizen participation, open government",
    "meta_title": "CONSUL DEMO",
    "mailer_from_address": "noreply@demo.consulproject.org",
    "mailer_from_name": "CONSUL",
    "feature.map": true,
    "map.latitude": 51.51,
    "map.longitude": -0.05,
    "map.zoom": 13,
    "proposal_code_prefix": "DEMO",
    "proposal_notification_minimum_interval_in_days": 0,
    "votes_for_proposal_success": 5
  }.each do |name, value|
    Setting[name] = value
  end
end

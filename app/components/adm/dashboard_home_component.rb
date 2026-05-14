class Adm::DashboardHomeComponent < ApplicationComponent
  renders_one :notice,        Adm::Dashboard::NoticeComponent
  renders_one :header_row,    Adm::Dashboard::HeaderRowComponent
  renders_one :tiles,         Adm::Dashboard::TilesSectionComponent
  renders_one :team,          Adm::Dashboard::TeamComponent
  renders_one :contacts,      Adm::Dashboard::ContactsComponent
  renders_one :activity_feed, Adm::ActivityFeedComponent
end

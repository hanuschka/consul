class Kern::Table::InlineActionsComponent < ApplicationComponent
  renders_many :actions, Kern::Table::InlineActionComponent
end

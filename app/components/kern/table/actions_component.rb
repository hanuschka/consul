class Kern::Table::ActionsComponent < ApplicationComponent
  renders_many :actions, Kern::Table::ActionComponent
end

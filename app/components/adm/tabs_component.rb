# frozen_string_literal: true

class Adm::TabsComponent < ApplicationComponent
  Tab = Struct.new(:label, :url, :current, :icon, :data, :count, keyword_init: true) do
    def initialize(label:, url:, current: false, icon: nil, data: {}, count: nil)
      super
    end
  end

  attr_reader :tabs, :i18n_scope

  def initialize(
    tabs: [],
    i18n_scope: nil
  )
    @i18n_scope = i18n_scope
    @tabs = build_tabs(tabs)
  end

  def render?
    tabs.any?
  end

  private

  def build_tabs(tabs_data)
    tabs_data.map do |tab|
      case tab
      when Tab
        tab
      when Hash
        build_tab_from_hash(tab.symbolize_keys)
      when String
        build_tab_from_key(tab)
      when Symbol
        build_tab_from_key(tab.to_s)
      else
        tab
      end
    end
  end

  def build_tab_from_hash(hash)
    hash[:label] = translate_label(hash[:label]) if hash[:label].is_a?(Symbol)
    Tab.new(**hash)
  end

  def build_tab_from_key(key)
    Tab.new(
      label: translate_label(key),
      url: "##{key}",
      current: false
    )
  end

  def translate_label(key)
    return key unless i18n_scope.present?

    I18n.t("#{i18n_scope}.#{key}", default: key.to_s.humanize)
  end

  def tab_classes(tab)
    tab.current ? "adm-tab active" : "adm-tab"
  end

  def tab_data(tab)
    tab.data || {}
  end
end

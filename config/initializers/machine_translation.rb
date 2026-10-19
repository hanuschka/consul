require Rails.root.join("lib", "machine_translation").to_s
require Rails.root.join("lib", "machine_translation", "chrome_store").to_s
require Rails.root.join("lib", "machine_translation", "missing_keys").to_s
require Rails.root.join("lib", "machine_translation", "i18n_backend").to_s
require Rails.root.join("lib", "machine_translation", "setting_text").to_s

I18n::Backend::Simple.include(MachineTranslation::I18nBackend)

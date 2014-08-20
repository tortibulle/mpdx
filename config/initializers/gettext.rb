require 'gettext_i18n_rails/string_interpolate_fix'
FastGettext.add_text_domain 'mpdx', path: 'locale', type: :po, report_warning: false
FastGettext.default_text_domain = 'mpdx'
FastGettext.default_available_locales = ['en','de','fr','es']
GettextI18nRails.translations_are_html_safe = true

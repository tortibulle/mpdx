FastGettext.add_text_domain 'mpdx', :path => 'locale', :type => :po
FastGettext.default_text_domain = 'mpdx'
FastGettext.default_available_locales = ['en','de']
GettextI18nRails.translations_are_html_safe = true

class TntImportValidator < ActiveModel::Validator
  include ActionView::Helpers::UrlHelper
  def validate(import)
    if import.file.file
      tnt_import = TntImport.new(import)

      lines = tnt_import.read_csv(import.file.file.file)

      # Make sure required columns are present
      unless (lines.headers & TntImport.required_columns).length == TntImport.required_columns.length
        import.errors[:base] << _('You need to export all the available fields from TNT. Also make sure you export as a .csv, not the Excel option. If you continue to have issues, make sure you have watched %{link}, then send us an email to %{email} with a copy of your .csv file') %
          { link: link_to('http://screencast.com/t/lFiYn0EA4', 'http://screencast.com/t/lFiYn0EA4', target: '_blank'),
            email: mail_to('support@mpdx.org','support@mpdx.org') }
      end
    else
      import.errors[:base] << _('Please choose a file that ends with .csv')
    end
  end

end

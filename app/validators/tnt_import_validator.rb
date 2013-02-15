class TntImportValidator < ActiveModel::Validator
  include ActionView::Helpers::UrlHelper
  def validate(import)
    if import.file.file
      tnt_import = TntImport.new(import)

      xml = tnt_import.xml

      # Make sure required columns are present
      unless xml
        import.errors[:base] << _('The file you uploaded is not a valid Tnt export. %{link}') %
          { link: link_to(_('Please watch this video to see how to properly export from TntMPD.'), 'http://screencast.com/t/CU4y51KbRMkr', target: '_blank')}
      end
    else
      import.errors[:base] << _('Please choose a file that ends with .xml')
    end
  end

end

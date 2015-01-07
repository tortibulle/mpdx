class TntImportValidator < ActiveModel::Validator
  include ActionView::Helpers::UrlHelper
  def validate(import)
    # ImportUpload makes sure the file ends in .xml, we just need to to check that it's present here
    unless import.file.present?
      import.errors[:base] << _('You must specify a TntMPD .xml export file to upload to MPDX (see video linked below for more info).')
    end
  end
end

class TntImportValidator < ActiveModel::Validator
  def validate(import)
    if import.file.file
      tnt_import = TntImport.new(import)
      begin
        @file = File.open(import.file.file.file, "r:utf-8")
        lines = tnt_import.get_lines(@file.read)
      rescue ArgumentError
        @file = File.open(import.file.file.file, "r:windows-1251:utf-8")
        lines = tnt_import.get_lines(@file.read)
      end

      # Make sure required columns are present
      unless (lines.headers & TntImport.required_columns).length == TntImport.required_columns.length
        import.errors[:base] << _('You need to export all the available fields from TNT')
      end
    else
      import.errors[:base] << _('Please choose a file that ends with .csv')
    end
  end

end

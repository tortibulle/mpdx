class TntImportValidator < ActiveModel::Validator
  def validate(import)
    if import.file.file
      begin
        @file = File.open(import.file.file.file, "r:utf-8")
        lines = get_lines(@file.read)
      rescue ArgumentError
        @file = File.open(import.file.file.file, "r:windows-1251:utf-8")
        lines = get_lines(@file.read)
      end
      contents = @file.read
      contents = contents[1..-1] if TwitterCldr::Utils::CodePoints.from_string(contents.first).first == "FEFF"
      # Make sure required columns are present
      required_columns = ['ContactID', 'Is Organization', 'Organization Account IDs']

      unless (lines.headers & required_columns).length == required_columns.length
        import.errors[:base] << _('You need to export all the available fields from TNT')
      end
    else
      import.errors[:base] << _('Please choose a file that ends with .csv')
    end
  end

  def get_lines(contents)
    # Strip annoying tnt unicode character
    contents = contents[1..-1] if TwitterCldr::Utils::CodePoints.from_string(contents.first).first == "FEFF"
    CSV.parse(contents, headers: true)
  end
end

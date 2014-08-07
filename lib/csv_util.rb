require 'nokogiri'
require 'csv'

module CSVUtil
  def html_table_to_csv(html_table)
    CSV.generate do |csv|
      Nokogiri::HTML(html_table).xpath('//table//tr').each do |row|
        csv << (row.xpath('th') + row.xpath('td')).map { |cell| cell.text.strip }
      end
    end
  end
  module_function :html_table_to_csv
end

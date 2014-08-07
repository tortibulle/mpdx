require 'csv_util'

describe CSVUtil do
  describe 'html_table_to_csv' do
    it 'should convert html tables to csv' do
      expect(CSVUtil.html_table_to_csv <<-EOS
        <table>
          <tr><td>A</td><td>B</td></tr>
          <tr><td>1</td><td>2</td></tr>
        </table>
              EOS
              ).to eq(<<-EOS
A,B
1,2
        EOS
      )

      expect(CSVUtil.html_table_to_csv <<-EOS
        <table>
          <tr><td>A</td><td>B</td></tr>
          <tr><td>1,
          "</td>
          <td>2</td></tr>
        </table>
              EOS
              ).to eq(<<-EOS
A,B
"1,
          """,2
        EOS
      )

      expect(CSVUtil.html_table_to_csv <<-EOS
        <table>
          <thead>
            <tr>
                <th>
                A
                </th>
                <th> B </th>
            </tr>
          </thead>
          <tbody>
              <tr>
                <td>
                    1
                </td>
                <td>2</td>
              </tr>
          </tbody>
        </table>
        EOS
      ).to eq(<<-EOS
A,B
1,2
        EOS
      )
    end
  end
end

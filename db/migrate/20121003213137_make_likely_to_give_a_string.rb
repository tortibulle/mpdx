class MakeLikelyToGiveAString < ActiveRecord::Migration
  def up
    change_column :contacts, :likely_to_give, :string
    Contact.where(likely_to_give: '1').update_all(likely_to_give: 'Least Likely')
    Contact.where(likely_to_give: '2').update_all(likely_to_give: 'Likely')
    Contact.where(likely_to_give: '3').update_all(likely_to_give: 'Most Likely')
  end

  def down
    change_column :contacts, :likely_to_give, :integer
  end
end

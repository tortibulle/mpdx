class UpdateNzlEndpoint < ActiveRecord::Migration
  def change
  	cccnz = Organization.find_by_name("Campus Crusade for Christ - NZ")
  	tandem = Organization.find_by_name("Tandem Ministries")

  	unless cccnz.nil?
			cccnz.query_ini_url = "https://tntdataserverasia.com/dataserver/nzl/dataquery/tntquery.aspx"
  		cccnz.save
  		say "Updated Campus Crusade for Christ - NZ"
  	end

  	unless tandem.nil?
			tandem.query_ini_url = "https://tntdataserverasia.com/dataserver/nzl/dataquery/tntquery.aspx"
  		tandem.save
  		say "Updated Tandem Ministries"
  	end
  end
end

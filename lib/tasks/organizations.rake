# encoding: utf-8
require 'open-uri'
require 'csv'

namespace :organizations do
  task fetch: :environment do
    # Download the org csv from tnt and update orgs
    CSV.new(open('http://download.tntware.com/tntmpd/TntMPD_Organizations.csv'), :headers => :first_row).each do |line|
      attributes = {name: line[0], query_ini_url: line[1], iso3166: line[2]}
      next unless attributes[:query_ini_url]
      org = Organization.where(attributes.slice(:query_ini_url)).first_or_create(attributes)
      # Grab latest query.ini file for this org
      begin
        uri = URI.parse(org.query_ini_url)
        ini_body = uri.read("r:UTF-8")
        # remove unicode characters if present
        ini_body = ini_body[1..-1] unless ini_body.first == '['
        ini = IniParse.parse(ini_body)
        attributes[:redirect_query_ini] = ini['ORGANIZATION']['RedirectQueryIni']
        attributes[:abbreviation] = ini['ORGANIZATION']['Abbreviation']
        #attributes[:name] = ini['ORGANIZATION']['Name']
        attributes[:abbreviation] = ini['ORGANIZATION']['Abbreviation']
        attributes[:logo] = ini['ORGANIZATION']['WebLogo-JPEG-470x120']
        attributes[:account_help_url] = ini['ORGANIZATION']['AccountHelpUrl']
        attributes[:minimum_gift_date] = ini['ORGANIZATION']['MinimumWebGiftDate']
        attributes[:code] = ini['ORGANIZATION']['Code']
        attributes[:query_authentication] = ini['ORGANIZATION']['QueryAuthentication'].to_i == 1
        attributes[:org_help_email] = ini['ORGANIZATION']['OrgHelpEmail']
        attributes[:org_help_url] = ini['ORGANIZATION']['OrgHelpUrl']
        attributes[:org_help_url_description] = ini['ORGANIZATION']['OrgHelpUrlDescription']
        attributes[:org_help_other] = ini['ORGANIZATION']['OrgHelpOther']
        attributes[:request_profile_url] = ini['ORGANIZATION']['RequestProfileUrl']
        attributes[:staff_portal_url] = ini['ORGANIZATION']['StaffPortalUrl']
        attributes[:default_currency_code] = ini['ORGANIZATION']['DefaultCurrencyCode']
        attributes[:allow_passive_auth] = ini['ORGANIZATION']['AllowPassiveAuth'] == 'True'
        %w{account_balance donations addresses addresses_by_personids profiles designations}.each do |section|
          keys = ini.collect {|k,v|
            k.key =~ /^#{section.upcase}[\.\d]*$/ ? k.key : nil
          }.compact.sort.reverse
          keys.each do |k|
            if attributes["#{section}_url"].nil? && ini[k]['Url']
              attributes["#{section}_url"] = ini[k]['Url']
            end
            if attributes["#{section}_params"].nil? && ini[k]['Post']
              attributes["#{section}_params"] = ini[k]['Post']
            end
          end
        end
        puts "\nSUCCESS: #{org.query_ini_url}\n\n"
      rescue => e
        puts "failed on #{org.query_ini_url}"
        puts e.message
      end
      org.update_attributes(attributes)
    end
  end
end

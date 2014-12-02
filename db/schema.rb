# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20141201142757) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "account_list_entries", force: true do |t|
    t.integer  "account_list_id"
    t.integer  "designation_account_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "account_list_entries", ["account_list_id", "designation_account_id"], name: "unique_account", unique: true, using: :btree
  add_index "account_list_entries", ["designation_account_id"], name: "index_account_list_entries_on_designation_account_id", using: :btree

  create_table "account_list_users", force: true do |t|
    t.integer  "user_id"
    t.integer  "account_list_id"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "account_list_users", ["account_list_id"], name: "index_account_list_users_on_account_list_id", using: :btree
  add_index "account_list_users", ["user_id", "account_list_id"], name: "index_account_list_users_on_user_id_and_account_list_id", unique: true, using: :btree

  create_table "account_lists", force: true do |t|
    t.string   "name"
    t.integer  "creator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text     "settings"
  end

  add_index "account_lists", ["creator_id"], name: "index_account_lists_on_creator_id", using: :btree

  create_table "active_admin_comments", force: true do |t|
    t.string   "resource_id",   null: false
    t.string   "resource_type", null: false
    t.integer  "author_id"
    t.string   "author_type"
    t.text     "body"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
    t.string   "namespace"
  end

  add_index "active_admin_comments", ["author_type", "author_id"], name: "index_active_admin_comments_on_author_type_and_author_id", using: :btree
  add_index "active_admin_comments", ["namespace"], name: "index_active_admin_comments_on_namespace", using: :btree
  add_index "active_admin_comments", ["resource_type", "resource_id"], name: "index_admin_notes_on_resource_type_and_resource_id", using: :btree

  create_table "activities", force: true do |t|
    t.integer  "account_list_id"
    t.boolean  "starred",                              default: false, null: false
    t.string   "location"
    t.string   "subject",                 limit: 2000
    t.datetime "start_at"
    t.datetime "end_at"
    t.string   "type"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.boolean  "completed",                            default: false, null: false
    t.integer  "activity_comments_count",              default: 0
    t.string   "activity_type"
    t.string   "result"
    t.datetime "completed_at"
    t.integer  "notification_id"
    t.string   "remote_id"
    t.string   "source"
    t.string   "next_action"
  end

  add_index "activities", ["account_list_id"], name: "index_activities_on_account_list_id", using: :btree
  add_index "activities", ["activity_type"], name: "index_activities_on_activity_type", using: :btree
  add_index "activities", ["notification_id"], name: "index_activities_on_notification_id", using: :btree
  add_index "activities", ["start_at"], name: "index_activities_on_start_at", using: :btree

  create_table "activity_comments", force: true do |t|
    t.integer  "activity_id"
    t.integer  "person_id"
    t.text     "body"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "activity_comments", ["activity_id"], name: "index_activity_comments_on_activity_id", using: :btree
  add_index "activity_comments", ["person_id"], name: "index_activity_comments_on_person_id", using: :btree

  create_table "activity_contacts", force: true do |t|
    t.integer  "activity_id"
    t.integer  "contact_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "activity_contacts", ["activity_id", "contact_id"], name: "index_activity_contacts_on_activity_id_and_contact_id", using: :btree
  add_index "activity_contacts", ["contact_id", "activity_id"], name: "index_activity_contacts_on_contact_id_and_activity_id", unique: true, using: :btree
  add_index "activity_contacts", ["contact_id"], name: "index_activity_contacts_on_contact_id", using: :btree

  create_table "addresses", force: true do |t|
    t.integer  "addressable_id"
    t.text     "street"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "postal_code"
    t.string   "location"
    t.date     "start_date"
    t.date     "end_date"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.boolean  "primary_mailing_address", default: false
    t.string   "addressable_type"
    t.string   "remote_id"
    t.boolean  "seasonal",                default: false
    t.integer  "master_address_id"
    t.boolean  "verified",                default: false, null: false
    t.boolean  "deleted",                 default: false, null: false
    t.string   "region"
    t.string   "metro_area"
    t.boolean  "historic",                default: false
  end

  add_index "addresses", ["addressable_id"], name: "index_addresses_on_person_id", using: :btree
  add_index "addresses", ["master_address_id"], name: "index_addresses_on_master_address_id", using: :btree
  add_index "addresses", ["remote_id"], name: "index_addresses_on_remote_id", using: :btree

  create_table "admin_users", force: true do |t|
    t.string   "email",                default: "", null: false
    t.string   "guid",                              null: false
    t.integer  "sign_in_count",        default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "authentication_token"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  add_index "admin_users", ["authentication_token"], name: "index_admin_users_on_authentication_token", unique: true, using: :btree
  add_index "admin_users", ["email"], name: "index_admin_users_on_email", unique: true, using: :btree
  add_index "admin_users", ["guid"], name: "index_admin_users_on_guid", unique: true, using: :btree

  create_table "appeal_contacts", force: true do |t|
    t.integer  "appeal_id"
    t.integer  "contact_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "appeal_contacts", ["appeal_id", "contact_id"], name: "index_appeal_contacts_on_appeal_id_and_contact_id", using: :btree
  add_index "appeal_contacts", ["appeal_id"], name: "index_appeal_contacts_on_appeal_id", using: :btree
  add_index "appeal_contacts", ["contact_id"], name: "index_appeal_contacts_on_contact_id", using: :btree

  create_table "appeals", force: true do |t|
    t.string   "name"
    t.integer  "account_list_id"
    t.decimal  "amount",          precision: 8, scale: 2
    t.text     "description"
    t.date     "end_date"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "appeals", ["account_list_id"], name: "index_appeals_on_account_list_id", using: :btree

  create_table "companies", force: true do |t|
    t.string   "name"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.text     "street"
    t.string   "city"
    t.string   "state"
    t.string   "postal_code"
    t.string   "country"
    t.string   "phone_number"
    t.integer  "master_company_id"
  end

  create_table "company_partnerships", force: true do |t|
    t.integer  "account_list_id"
    t.integer  "company_id"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "company_partnerships", ["account_list_id", "company_id"], name: "unique_company_account", unique: true, using: :btree
  add_index "company_partnerships", ["company_id"], name: "index_company_partnerships_on_company_id", using: :btree

  create_table "company_positions", force: true do |t|
    t.integer  "person_id",  null: false
    t.integer  "company_id", null: false
    t.date     "start_date"
    t.date     "end_date"
    t.string   "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "company_positions", ["company_id"], name: "index_company_positions_on_company_id", using: :btree
  add_index "company_positions", ["person_id"], name: "index_company_positions_on_person_id", using: :btree
  add_index "company_positions", ["start_date"], name: "index_company_positions_on_start_date", using: :btree

  create_table "contact_donor_accounts", force: true do |t|
    t.integer  "contact_id"
    t.integer  "donor_account_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "contact_donor_accounts", ["contact_id"], name: "index_contact_donor_accounts_on_contact_id", using: :btree
  add_index "contact_donor_accounts", ["donor_account_id"], name: "index_contact_donor_accounts_on_donor_account_id", using: :btree

  create_table "contact_people", force: true do |t|
    t.integer  "contact_id"
    t.integer  "person_id"
    t.boolean  "primary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "contact_people", ["contact_id", "person_id"], name: "index_contact_people_on_contact_id_and_person_id", unique: true, using: :btree
  add_index "contact_people", ["person_id"], name: "index_contact_people_on_person_id", using: :btree

  create_table "contact_referrals", force: true do |t|
    t.integer  "referred_by_id"
    t.integer  "referred_to_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "contact_referrals", ["referred_by_id", "referred_to_id"], name: "referrals", using: :btree
  add_index "contact_referrals", ["referred_to_id"], name: "index_contact_referrals_on_referred_to_id", using: :btree

  create_table "contacts", force: true do |t|
    t.string   "name"
    t.integer  "account_list_id"
    t.datetime "created_at",                                                                    null: false
    t.datetime "updated_at",                                                                    null: false
    t.decimal  "pledge_amount",                        precision: 8,  scale: 2
    t.string   "status"
    t.decimal  "total_donations",                      precision: 10, scale: 2
    t.date     "last_donation_date"
    t.date     "first_donation_date"
    t.text     "notes"
    t.datetime "notes_saved_at"
    t.string   "full_name"
    t.string   "greeting"
    t.string   "website",                 limit: 1000
    t.decimal  "pledge_frequency"
    t.date     "pledge_start_date"
    t.date     "next_ask"
    t.boolean  "never_ask",                                                     default: false, null: false
    t.string   "likely_to_give"
    t.string   "church_name"
    t.string   "send_newsletter"
    t.boolean  "direct_deposit",                                                default: false, null: false
    t.boolean  "magazine",                                                      default: false, null: false
    t.date     "last_activity"
    t.date     "last_appointment"
    t.date     "last_letter"
    t.date     "last_phone_call"
    t.date     "last_pre_call"
    t.date     "last_thank"
    t.boolean  "pledge_received",                                               default: false, null: false
    t.integer  "tnt_id"
    t.string   "not_duplicated_with",     limit: 2000
    t.integer  "uncompleted_tasks_count",                                       default: 0,     null: false
    t.string   "prayer_letters_id",       limit: 100
    t.string   "timezone"
  end

  add_index "contacts", ["account_list_id"], name: "index_contacts_on_account_list_id", using: :btree
  add_index "contacts", ["last_donation_date"], name: "index_contacts_on_last_donation_date", using: :btree
  add_index "contacts", ["tnt_id"], name: "index_contacts_on_tnt_id", using: :btree
  add_index "contacts", ["total_donations"], name: "index_contacts_on_total_donations", using: :btree

  create_table "designation_accounts", force: true do |t|
    t.string   "designation_number"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.integer  "organization_id"
    t.decimal  "balance",            precision: 19, scale: 2
    t.datetime "balance_updated_at"
    t.string   "name"
    t.string   "staff_account_id"
    t.string   "chartfield"
  end

  add_index "designation_accounts", ["organization_id", "designation_number"], name: "unique_designation_org", unique: true, using: :btree

  create_table "designation_profile_accounts", force: true do |t|
    t.integer  "designation_profile_id"
    t.integer  "designation_account_id"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  add_index "designation_profile_accounts", ["designation_profile_id", "designation_account_id"], name: "designation_p_to_a", unique: true, using: :btree

  create_table "designation_profiles", force: true do |t|
    t.string   "remote_id"
    t.integer  "user_id",                                     null: false
    t.integer  "organization_id",                             null: false
    t.string   "name"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "code"
    t.decimal  "balance",            precision: 19, scale: 2
    t.datetime "balance_updated_at"
    t.integer  "account_list_id"
  end

  add_index "designation_profiles", ["account_list_id"], name: "index_designation_profiles_on_account_list_id", using: :btree
  add_index "designation_profiles", ["organization_id"], name: "index_designation_profiles_on_organization_id", using: :btree
  add_index "designation_profiles", ["user_id", "organization_id", "remote_id"], name: "unique_remote_id", unique: true, using: :btree

  create_table "donations", force: true do |t|
    t.string   "remote_id"
    t.integer  "donor_account_id"
    t.integer  "designation_account_id"
    t.string   "motivation"
    t.string   "payment_method"
    t.string   "tendered_currency"
    t.decimal  "tendered_amount",        precision: 8, scale: 2
    t.string   "currency"
    t.decimal  "amount",                 precision: 8, scale: 2
    t.text     "memo"
    t.date     "donation_date"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.string   "payment_type"
    t.string   "channel"
    t.integer  "appeal_id"
  end

  add_index "donations", ["appeal_id"], name: "index_donations_on_appeal_id", using: :btree
  add_index "donations", ["designation_account_id", "remote_id"], name: "unique_donation_designation", unique: true, using: :btree
  add_index "donations", ["donation_date"], name: "index_donations_on_donation_date", using: :btree
  add_index "donations", ["donor_account_id"], name: "index_donations_on_donor_account_id", using: :btree

  create_table "donor_account_people", force: true do |t|
    t.integer  "donor_account_id"
    t.integer  "person_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "donor_account_people", ["donor_account_id"], name: "index_donor_account_people_on_donor_account_id", using: :btree
  add_index "donor_account_people", ["person_id"], name: "index_donor_account_people_on_person_id", using: :btree

  create_table "donor_accounts", force: true do |t|
    t.integer  "organization_id"
    t.string   "account_number"
    t.string   "name"
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.integer  "master_company_id"
    t.decimal  "total_donations",                precision: 10, scale: 2
    t.date     "last_donation_date"
    t.date     "first_donation_date"
    t.string   "donor_type",          limit: 20
  end

  add_index "donor_accounts", ["last_donation_date"], name: "index_donor_accounts_on_last_donation_date", using: :btree
  add_index "donor_accounts", ["organization_id", "account_number"], name: "index_donor_accounts_on_organization_id_and_account_number", unique: true, using: :btree
  add_index "donor_accounts", ["organization_id"], name: "index_donor_accounts_on_organization_id", using: :btree
  add_index "donor_accounts", ["total_donations"], name: "index_donor_accounts_on_total_donations", using: :btree

  create_table "email_addresses", force: true do |t|
    t.integer  "person_id"
    t.string   "email",                                 null: false
    t.boolean  "primary",               default: false
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.string   "remote_id"
    t.string   "location",   limit: 50
    t.boolean  "historic",              default: false
    t.boolean  "bad",                   default: false, null: false
  end

  add_index "email_addresses", ["email", "person_id"], name: "index_email_addresses_on_email_and_person_id", unique: true, using: :btree
  add_index "email_addresses", ["person_id"], name: "index_email_addresses_on_person_id", using: :btree
  add_index "email_addresses", ["remote_id"], name: "index_email_addresses_on_remote_id", using: :btree

  create_table "family_relationships", force: true do |t|
    t.integer  "person_id"
    t.integer  "related_person_id"
    t.string   "relationship"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "family_relationships", ["person_id", "related_person_id"], name: "index_family_relationships_on_person_id_and_related_person_id", unique: true, using: :btree
  add_index "family_relationships", ["related_person_id"], name: "index_family_relationships_on_related_person_id", using: :btree

  create_table "google_contacts", force: true do |t|
    t.string   "remote_id"
    t.integer  "person_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "picture_etag"
    t.integer  "picture_id"
    t.integer  "google_account_id"
    t.datetime "last_synced"
    t.string   "last_etag"
    t.text     "last_data"
    t.integer  "contact_id"
  end

  add_index "google_contacts", ["contact_id"], name: "index_google_contacts_on_contact_id", using: :btree
  add_index "google_contacts", ["google_account_id"], name: "index_google_contacts_on_google_account_id", using: :btree
  add_index "google_contacts", ["person_id", "contact_id"], name: "index_google_contacts_on_person_id_and_contact_id", using: :btree
  add_index "google_contacts", ["person_id"], name: "index_google_contacts_on_person_id", using: :btree
  add_index "google_contacts", ["remote_id"], name: "index_google_contacts_on_remote_id", using: :btree

  create_table "google_email_activities", force: true do |t|
    t.integer  "google_email_id"
    t.integer  "activity_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "google_emails", force: true do |t|
    t.integer  "google_account_id"
    t.integer  "google_email_id",   limit: 8
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "google_events", force: true do |t|
    t.integer  "activity_id"
    t.integer  "google_integration_id"
    t.string   "google_event_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "google_events", ["activity_id"], name: "index_google_events_on_activity_id", using: :btree
  add_index "google_events", ["google_integration_id"], name: "index_google_events_on_google_integration_id", using: :btree

  create_table "google_integrations", force: true do |t|
    t.integer  "account_list_id"
    t.integer  "google_account_id"
    t.boolean  "calendar_integration",  default: false, null: false
    t.text     "calendar_integrations"
    t.string   "calendar_id"
    t.string   "calendar_name"
    t.boolean  "email_integration",     default: false, null: false
    t.boolean  "contacts_integration",  default: false, null: false
    t.datetime "contacts_last_synced"
  end

  add_index "google_integrations", ["account_list_id"], name: "index_google_integrations_on_account_list_id", using: :btree
  add_index "google_integrations", ["google_account_id"], name: "index_google_integrations_on_google_account_id", using: :btree

  create_table "help_requests", force: true do |t|
    t.string   "name"
    t.text     "browser"
    t.text     "problem"
    t.string   "email"
    t.string   "file"
    t.integer  "user_id"
    t.integer  "account_list_id"
    t.text     "session"
    t.text     "user_preferences"
    t.text     "account_list_settings"
    t.string   "request_type"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
  end

  create_table "imports", force: true do |t|
    t.integer  "account_list_id"
    t.string   "source"
    t.string   "file"
    t.boolean  "importing"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.text     "tags"
    t.boolean  "override",          default: false, null: false
    t.integer  "user_id"
    t.integer  "source_account_id"
    t.boolean  "import_by_group",   default: false
    t.text     "groups"
    t.text     "group_tags"
  end

  add_index "imports", ["account_list_id"], name: "index_imports_on_account_list_id", using: :btree
  add_index "imports", ["user_id"], name: "index_imports_on_user_id", using: :btree

  create_table "mail_chimp_accounts", force: true do |t|
    t.string   "api_key"
    t.boolean  "active",          default: false
    t.integer  "grouping_id"
    t.string   "primary_list_id"
    t.integer  "account_list_id"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "mail_chimp_accounts", ["account_list_id"], name: "index_mail_chimp_accounts_on_account_list_id", using: :btree

  create_table "master_addresses", force: true do |t|
    t.text     "street"
    t.string   "city"
    t.string   "state"
    t.string   "country"
    t.string   "postal_code"
    t.boolean  "verified",        default: false, null: false
    t.text     "smarty_response"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "master_addresses", ["street", "city", "state", "country", "postal_code"], name: "all_fields", using: :btree

  create_table "master_companies", force: true do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "master_people", force: true do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "master_person_donor_accounts", force: true do |t|
    t.integer  "master_person_id"
    t.integer  "donor_account_id"
    t.boolean  "primary",          default: false, null: false
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "master_person_donor_accounts", ["donor_account_id"], name: "index_master_person_donor_accounts_on_donor_account_id", using: :btree
  add_index "master_person_donor_accounts", ["master_person_id", "donor_account_id"], name: "person_account", unique: true, using: :btree

  create_table "master_person_sources", force: true do |t|
    t.integer  "master_person_id"
    t.integer  "organization_id"
    t.string   "remote_id"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
  end

  add_index "master_person_sources", ["master_person_id"], name: "index_master_person_sources_on_master_person_id", using: :btree
  add_index "master_person_sources", ["organization_id", "remote_id"], name: "organization_remote_id", unique: true, using: :btree

  create_table "messages", force: true do |t|
    t.integer  "from_id"
    t.integer  "to_id"
    t.string   "subject"
    t.text     "body"
    t.datetime "sent_at"
    t.string   "source"
    t.string   "remote_id"
    t.integer  "contact_id"
    t.integer  "account_list_id"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
  end

  add_index "messages", ["account_list_id"], name: "index_messages_on_account_list_id", using: :btree
  add_index "messages", ["contact_id"], name: "index_messages_on_contact_id", using: :btree
  add_index "messages", ["from_id"], name: "index_messages_on_from_id", using: :btree
  add_index "messages", ["to_id"], name: "index_messages_on_to_id", using: :btree

  create_table "notification_preferences", force: true do |t|
    t.integer  "notification_type_id"
    t.integer  "account_list_id"
    t.text     "actions"
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "notification_preferences", ["account_list_id"], name: "index_notification_preferences_on_account_list_id", using: :btree
  add_index "notification_preferences", ["notification_type_id"], name: "index_notification_preferences_on_notification_type_id", using: :btree

  create_table "notification_types", force: true do |t|
    t.string   "type"
    t.text     "description"
    t.datetime "created_at",            null: false
    t.datetime "updated_at",            null: false
    t.text     "description_for_email"
  end

  create_table "notifications", force: true do |t|
    t.integer  "contact_id"
    t.integer  "notification_type_id"
    t.datetime "event_date"
    t.boolean  "cleared",              default: false, null: false
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.integer  "donation_id"
  end

  add_index "notifications", ["contact_id", "notification_type_id", "donation_id"], name: "notification_index", using: :btree
  add_index "notifications", ["contact_id"], name: "index_notifications_on_contact_id", using: :btree
  add_index "notifications", ["donation_id"], name: "index_notifications_on_donation_id", using: :btree
  add_index "notifications", ["notification_type_id"], name: "index_notifications_on_notification_type_id", using: :btree

  create_table "organizations", force: true do |t|
    t.string   "name"
    t.string   "query_ini_url"
    t.string   "iso3166"
    t.string   "minimum_gift_date"
    t.string   "logo"
    t.string   "code"
    t.boolean  "query_authentication"
    t.string   "account_help_url"
    t.string   "abbreviation"
    t.string   "org_help_email"
    t.string   "org_help_url"
    t.string   "org_help_url_description"
    t.text     "org_help_other"
    t.string   "request_profile_url"
    t.string   "staff_portal_url"
    t.string   "default_currency_code"
    t.boolean  "allow_passive_auth"
    t.string   "account_balance_url"
    t.string   "account_balance_params"
    t.string   "donations_url"
    t.string   "donations_params"
    t.string   "addresses_url"
    t.string   "addresses_params"
    t.string   "addresses_by_personids_url"
    t.string   "addresses_by_personids_params"
    t.string   "profiles_url"
    t.string   "profiles_params"
    t.string   "redirect_query_ini"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.string   "api_class"
  end

  add_index "organizations", ["query_ini_url"], name: "index_organizations_on_query_ini_url", unique: true, using: :btree

  create_table "people", force: true do |t|
    t.string   "first_name",                                       null: false
    t.string   "legal_first_name"
    t.string   "last_name"
    t.integer  "birthday_month"
    t.integer  "birthday_year"
    t.integer  "birthday_day"
    t.integer  "anniversary_month"
    t.integer  "anniversary_year"
    t.integer  "anniversary_day"
    t.string   "title"
    t.string   "suffix"
    t.string   "gender"
    t.string   "marital_status"
    t.text     "preferences"
    t.integer  "sign_in_count",                    default: 0
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
    t.integer  "master_person_id",                                 null: false
    t.string   "middle_name"
    t.string   "access_token",          limit: 32
    t.string   "profession"
    t.boolean  "deceased",                         default: false, null: false
    t.boolean  "subscribed_to_updates"
    t.boolean  "optout_enewsletter",               default: false
    t.string   "occupation"
    t.string   "employer"
  end

  add_index "people", ["access_token"], name: "index_people_on_access_token", unique: true, using: :btree
  add_index "people", ["first_name"], name: "index_people_on_first_name", using: :btree
  add_index "people", ["last_name"], name: "index_people_on_last_name", using: :btree
  add_index "people", ["master_person_id"], name: "index_people_on_master_person_id", using: :btree

  create_table "person_facebook_accounts", force: true do |t|
    t.integer  "person_id",                                  null: false
    t.integer  "remote_id",        limit: 8,                 null: false
    t.string   "token"
    t.datetime "token_expires_at"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
    t.boolean  "valid_token",                default: false
    t.string   "first_name"
    t.string   "last_name"
    t.boolean  "authenticated",              default: false, null: false
    t.boolean  "downloading",                default: false, null: false
    t.datetime "last_download"
  end

  add_index "person_facebook_accounts", ["person_id", "remote_id"], name: "index_person_facebook_accounts_on_person_id_and_remote_id", unique: true, using: :btree
  add_index "person_facebook_accounts", ["remote_id"], name: "index_person_facebook_accounts_on_remote_id", using: :btree

  create_table "person_google_accounts", force: true do |t|
    t.string   "remote_id"
    t.integer  "person_id"
    t.string   "token"
    t.string   "refresh_token"
    t.datetime "expires_at"
    t.boolean  "valid_token",     default: false
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "email",                           null: false
    t.boolean  "authenticated",   default: false, null: false
    t.boolean  "primary",         default: false
    t.boolean  "downloading",     default: false, null: false
    t.datetime "last_download"
    t.datetime "last_email_sync"
  end

  add_index "person_google_accounts", ["person_id"], name: "index_person_google_accounts_on_person_id", using: :btree
  add_index "person_google_accounts", ["remote_id"], name: "index_person_google_accounts_on_remote_id", using: :btree

  create_table "person_key_accounts", force: true do |t|
    t.integer  "person_id"
    t.string   "remote_id"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.boolean  "authenticated", default: false, null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.boolean  "primary",       default: false
    t.boolean  "downloading",   default: false, null: false
    t.datetime "last_download"
  end

  add_index "person_key_accounts", ["person_id"], name: "index_person_key_accounts_on_person_id", using: :btree
  add_index "person_key_accounts", ["remote_id"], name: "index_person_key_accounts_on_remote_id", using: :btree

  create_table "person_linkedin_accounts", force: true do |t|
    t.integer  "person_id",                        null: false
    t.string   "remote_id",                        null: false
    t.string   "token"
    t.string   "secret"
    t.datetime "token_expires_at"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.boolean  "valid_token",      default: false
    t.string   "first_name"
    t.string   "last_name"
    t.boolean  "authenticated",    default: false, null: false
    t.boolean  "downloading",      default: false, null: false
    t.datetime "last_download"
    t.string   "public_url"
  end

  add_index "person_linkedin_accounts", ["person_id", "remote_id"], name: "index_person_linkedin_accounts_on_person_id_and_remote_id", unique: true, using: :btree
  add_index "person_linkedin_accounts", ["remote_id"], name: "index_person_linkedin_accounts_on_remote_id", using: :btree

  create_table "person_organization_accounts", force: true do |t|
    t.integer  "person_id"
    t.integer  "organization_id"
    t.string   "username"
    t.string   "password"
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
    t.string   "remote_id"
    t.boolean  "authenticated",     default: false, null: false
    t.boolean  "valid_credentials", default: false, null: false
    t.boolean  "downloading",       default: false, null: false
    t.datetime "last_download"
    t.string   "token"
    t.datetime "locked_at"
  end

  add_index "person_organization_accounts", ["person_id", "organization_id"], name: "index_organization_accounts_on_user_id_and_organization_id", unique: true, using: :btree

  create_table "person_relay_accounts", force: true do |t|
    t.integer  "person_id"
    t.string   "remote_id"
    t.string   "first_name"
    t.string   "last_name"
    t.string   "email"
    t.string   "designation"
    t.string   "employee_id"
    t.string   "username"
    t.boolean  "authenticated", default: false, null: false
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.boolean  "primary",       default: false
    t.boolean  "downloading",   default: false, null: false
    t.datetime "last_download"
  end

  add_index "person_relay_accounts", ["person_id"], name: "index_person_relay_accounts_on_person_id", using: :btree
  add_index "person_relay_accounts", ["remote_id"], name: "index_person_relay_accounts_on_remote_id", using: :btree

  create_table "person_twitter_accounts", force: true do |t|
    t.integer  "person_id",                               null: false
    t.integer  "remote_id",     limit: 8,                 null: false
    t.string   "screen_name"
    t.string   "token"
    t.string   "secret"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.boolean  "valid_token",             default: false
    t.boolean  "authenticated",           default: false, null: false
    t.boolean  "primary",                 default: false
    t.boolean  "downloading",             default: false, null: false
    t.datetime "last_download"
  end

  add_index "person_twitter_accounts", ["person_id", "remote_id"], name: "index_person_twitter_accounts_on_person_id_and_remote_id", unique: true, using: :btree
  add_index "person_twitter_accounts", ["remote_id"], name: "index_person_twitter_accounts_on_remote_id", using: :btree

  create_table "person_websites", force: true do |t|
    t.integer  "person_id"
    t.string   "url"
    t.boolean  "primary",    default: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "person_websites", ["person_id"], name: "index_person_websites_on_person_id", using: :btree

  create_table "phone_numbers", force: true do |t|
    t.integer  "person_id"
    t.string   "number"
    t.string   "country_code"
    t.string   "location"
    t.boolean  "primary",      default: false
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.string   "remote_id"
  end

  add_index "phone_numbers", ["person_id"], name: "index_phone_numbers_on_person_id", using: :btree
  add_index "phone_numbers", ["remote_id"], name: "index_phone_numbers_on_remote_id", using: :btree

  create_table "pictures", force: true do |t|
    t.integer  "picture_of_id"
    t.string   "picture_of_type"
    t.string   "image"
    t.boolean  "primary",         default: false, null: false
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
  end

  add_index "pictures", ["picture_of_id", "picture_of_type"], name: "picture_of", using: :btree

  create_table "prayer_letters_accounts", force: true do |t|
    t.string   "token"
    t.string   "secret"
    t.boolean  "valid_token",     default: true
    t.datetime "created_at",                     null: false
    t.datetime "updated_at",                     null: false
    t.integer  "account_list_id"
    t.string   "oauth2_token"
  end

  add_index "prayer_letters_accounts", ["account_list_id"], name: "index_prayer_letters_accounts_on_account_list_id", using: :btree

  create_table "taggings", force: true do |t|
    t.integer  "tag_id"
    t.integer  "taggable_id"
    t.string   "taggable_type"
    t.integer  "tagger_id"
    t.string   "tagger_type"
    t.string   "context",       limit: 128
    t.datetime "created_at"
  end

  add_index "taggings", ["tag_id", "taggable_id", "taggable_type", "context", "tagger_id", "tagger_type"], name: "taggings_idx", unique: true, using: :btree
  add_index "taggings", ["taggable_id"], name: "INDEX_TAGGINGS_ON_TAGGABLE_ID", using: :btree

  create_table "tags", force: true do |t|
    t.string "name"
  end

  add_index "tags", ["name"], name: "index_tags_on_name", unique: true, using: :btree

  create_table "versions", force: true do |t|
    t.string   "item_type",           null: false
    t.integer  "item_id",             null: false
    t.string   "event",               null: false
    t.string   "whodunnit"
    t.text     "object"
    t.string   "related_object_type"
    t.integer  "related_object_id"
    t.datetime "created_at"
  end

  add_index "versions", ["item_type", "event", "related_object_type", "related_object_id", "created_at", "item_id"], name: "index_versions_on_item_type", using: :btree
  add_index "versions", ["item_type", "item_id", "related_object_type", "related_object_id", "created_at"], name: "related_object_index", using: :btree
  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree

end
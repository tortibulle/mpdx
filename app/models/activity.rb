class Activity < ActiveRecord::Base
  acts_as_taggable

  has_paper_trail :on => [:destroy],
                  :meta => { related_object_type: 'AccountList',
                             related_object_id: :account_list_id }

  belongs_to :account_list
  belongs_to :notification, inverse_of: :tasks
  has_many :activity_contacts, dependent: :destroy
  has_many :contacts, through: :activity_contacts
  has_many :activity_comments, dependent: :destroy
  has_many :people, through: :activity_comments

  scope :overdue, -> {where(completed: false).where('start_at < ?', Time.now.beginning_of_day).order('start_at')}
  scope :today, -> {where("start_at BETWEEN ? AND ?", Time.now.beginning_of_day, Time.now.end_of_day).order('start_at')}
  scope :tomorrow, -> {where("start_at BETWEEN ? AND ?", Time.now.end_of_day, Time.now.end_of_day + 1.day).order('start_at')}
  scope :upcoming, -> {where("start_at > ?", Time.now.end_of_day + 1.day).order('start_at')}
  scope :completed, -> { where(completed: true).order('completed_at desc, start_at desc') }
  scope :uncompleted, -> { where(completed: false).order('start_at') }
  scope :starred, -> { where(starred: true).order('start_at') }


  accepts_nested_attributes_for :activity_contacts, allow_destroy: true
  accepts_nested_attributes_for :activity_comments, reject_if: :all_blank

  # attr_accessible :starred, :location, :subject, :start_at, :end_at, :completed,
  #                 :activity_contacts_attributes, :activity_comments_attributes,
  #                 :contacts_attributes, :tag_list, :result, :notification_id,
  #                 :activity_type

  validates :subject, :start_at, presence: true

  def to_s() subject; end

  def contacts_attributes=(contacts_array)
    contacts_array = contacts_array.values if contacts_array.is_a?(Hash)
    contacts_array.each do |contact_attributes|
      contact = Contact.find(contact_attributes['id'])
      if contact_attributes['_destroy'].to_s == 'true'
        contacts.delete(contact) if contacts.include?(contact)
      else
        contacts << contact unless contacts.include?(contact)
      end
    end
  end

  def activity_contacts_attributes=(hash_or_array)
    contacts_array = hash_or_array.is_a?(Hash) ? hash_or_array.values : hash_or_array
    contacts_array.each do |contact_attributes|
      contact = Contact.find(contact_attributes['contact_id'])
      if contact_attributes['_destroy'].to_s == 'true'
        contacts.delete(contact) if contacts.include?(contact)
      else
        contacts << contact unless contacts.include?(contact)
      end
    end
  end

  def activity_comment=(hash)
    activity_comments.new(hash) if hash.values.any?(&:present?)
  end

end

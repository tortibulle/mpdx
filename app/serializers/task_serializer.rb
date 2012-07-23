class TaskSerializer < ActiveModel::Serializer
  embed :ids, include: true

  attributes :id, :account_list_id, :starred, :subject, :created_at, :updated_at, :completed
  attribute :activity_comments_count, key: :comments_count

  attribute :start_at, key: :due_date

  has_many :activity_comments, key: :comments

  private

  def attributes
    hash = super
    hash.merge!(contacts: task.contacts.collect(&:id))
    hash
  end
end

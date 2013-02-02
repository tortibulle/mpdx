class SocialItem
  From = Struct.new(:id, :name)
  To = Struct.new(:id, :name)
  Comment = Struct.new(:id, :from, :message, :created_time)
  Like = Struct.new(:id, :name)
  Action = Struct.new(:name, :link)
  StoryTag = Struct.new(:id, :name, :offset, :length, :type)
  FbApplication = Struct.new(:id, :name, :namespace)

  attr_accessor :id, :from, :to, :message, :picture, :link, :name, :caption, :description, :icon, :story, :story_tags, :type,
                :status_type, :created_time, :updated_time, :likes, :likes_count, :comments, :comments_count, :application,
                :object_id

  def initialize(json, names)
    %w[id message picture object_id type status_type link name caption description icon story].each do |field|
      send("#{field}=".to_sym, json[field]) if json[field].present?
    end
    @created_time = Time.at(json['created_time'])

    @from = From.new(json['actor_id'], names[json['actor_id']])
    @to = To.new(json['target_id'], names[json['target_id']]) if json['target_id'].present?

    #if json['actions']
      #@actions = []
      #json['actions'].each do |action|
        #@actions << Action.new(action['name'], action['link'])
      #end
    #end

    #if json['application']
      #@application = FbApplication.new(json['application']['id'], json['application']['name'], json['application']['namespace'])
    #end

    #if json['comments']
      #@comments_count = json['comments']['count']
      #if json['comments']['data']
        #@comments = []
        #json['comments']['data'].each do |comment|
          #@comments << Comment.new(comment['id'], From.new(comment['from']['id'], comment['from']['name']),
                                   #comment['message'], DateTime.parse(comment['created_time']))
        #end
      #end
    #end

    #if json['likes']
      #@likes_count = json['likes']['count']
      #if json['likes']['data']
        #@likes = []
        #json['likes']['data'].each do |like|
          #@likes << Like.new(like['id'], like['name'])
        #end
      #end
    #end

    #if json['story_tags']
      #@story_tags = []
      #json['story_tags'].values.flatten.each do |tag|
        #@story_tags << StoryTag.new(tag['id'], tag['name'], tag['offset'], tag['length'], tag['type'])
      #end
    #end


  end

  def body
    message || story || description
  end

  def <=>(other)
    other.created_time <=> created_time
  end
end

module PubTools
  class GitResource
    def self.from_id(id, **options)
      org, name = id.split('/')
      self.new(org, name, **options)
    end

    attr_reader :org, :name, :branch, :friendly_name, :trigger

    def initialize(org, name, **options)
      branch = options[:branch] || 'master'
      @org, @name, @branch = org, name, branch
      @trigger = options.fetch(:trigger, true)
      @friendly_name = options.fetch(:friendly_name, full_name)
      @friendly_name = 'cf-release' if name == 'cf-release'
    end

    def full_name
      parts = [name]
      parts << org if name == 'docs'
      parts << branch

      parts.join('-')
    end

    def eql?(other)
      self.org == other.org && self.name == other.name && self.branch == other.branch
    end

    def hash
      "PubTools::GitResource-#{org}-#{name}-#{branch}".hash
    end
  end
end

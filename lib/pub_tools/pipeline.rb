require 'pp'

module PubTools
  class ResourceConflictError < StandardError
    def initialize(previous, current)
      super(<<-MSG)
Unable to generate pipeline with conflicting resources:

#{previous.book_name}
#{'-' * previous.book_name.length}
#{previous.resource.pretty_inspect}

#{current.book_name}
#{'-' * current.book_name.length}
#{current.resource.pretty_inspect}
      MSG
    end
  end

  class Pipeline
    JobResource = Struct.new(:book_name, :resource)

    attr_reader :groups

    def initialize(schemes, deployment_resources, groups)
      @schemes, @deployment_resources, @groups = schemes, deployment_resources, groups
    end

    def resources
      schemes.each.with_object({}) { |(book_name, data), resources|
        data['sources'].each do |source|
          previous = resources[source['name']]
          current = JobResource.new(book_name, source)

          raise ResourceConflictError.new(previous, current) if previous && previous.resource != current.resource

          resources[source['name']] = current
        end
      }.values.map { |data| data[:resource] }.concat(deployment_resources)
    end

    def jobs
      schemes.map { |book_name, data| { 'name' =>  book_name, 'serial' => true, 'plan' => data['plan'] } }
    end

    def to_h
      { 'resources' => resources, 'jobs' => jobs, 'groups' => groups }
    end

    private

    attr_reader :schemes, :deployment_resources

  end
end

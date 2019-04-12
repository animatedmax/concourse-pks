require 'json'

module CfDeployment
  class CfAccount
    attr_reader :endpoint, :access_token, :organization, :space, :routes

    def initialize(options = {})
      @endpoint = options.fetch('endpoint')
      @username = options.fetch('username')
      @password = options.fetch('password')
      @organization = options.fetch('organization')
      @space = options.fetch('space')
      @routes = ensure_route_defaults(options.fetch('routes'))
    end

    def login
      unless system({'PASS' => password}, "cf login -a #{endpoint} -u #{username} -p $PASS -o #{organization} -s #{space}")
        raise 'Failed to login to CloudFoundry... exiting!'
      end

      @access_token = `cf oauth-token | grep bearer`
    end

    private

    def ensure_route_defaults(raw_routes)
      raw_routes.map do |route|
        { 'hostname' => '', 'path' => '' }.merge(route)
      end
    end

    attr_reader :username, :password
  end
end

require_relative 'page'

module CfDeployment
  class Indexer
    def initialize(root_path)
      @root_path = root_path
    end

    def parse_pages
      Dir.glob(File.join(@root_path, '**/*.html')).each do |file_path|
        relative_path = file_path.sub(@root_path, '').sub(/\A\//, '')
        next if excluded_path?(relative_path)

        page = Page.new(relative_path.sub(/\/index\.html\z/, '/'), File.read(file_path))

        next if page.to_h[:text] == ''

        yield page.to_h
      end
    end

    def excluded_path?(path)
      [
        /\A(index|404|owners)\.html\z/,
        /README\.html\z/,
        /\Asubnavs\//
      ].any? do |regex|
        path =~ regex
      end
    end
  end
end

require_relative 'git_resource'

module PubTools
  class Config
    attr_reader :book_repo

    def initialize(book_repo, input)
      @book_repo = book_repo
      @input = input
    end

    def concourse_scripts_docs_repo
      GitResource.new('pivotal-cf', 'concourse-scripts-docs', friendly_name: 'concourse-scripts', trigger: false)
    end

    def layout_repo
      if input.has_key?('layout_repo')
        GitResource.from_id(input.fetch('layout_repo'), branch: input['layout_repo_ref'], friendly_name: 'docs-layout-repo')
      end
    end

    def section_repos
      all_sections = (input['sections'] || []) + (input['dita_sections'] || [])

      dependent_sections = all_sections.map { |section| section['dependent_sections'] }.flatten.compact

      (all_sections + dependent_sections).map { |section|
        repository = section.fetch('repository')
        GitResource.from_id(repository.fetch('name'),
                     branch: repository['ref'])
      }.uniq
    end

    def all_repos
      repos = [concourse_scripts_docs_repo, book_repo]
      repos << layout_repo if layout_repo
      repos.concat(section_repos)
    end

    private

    attr_reader :input
  end
end

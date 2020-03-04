require "git-revision"

module Git
  class Revision
    class << self
      def dirty?
        !`git diff --numstat | wc -l`.strip.to_i.zero?
      end
    end
  end
end

def git_revision
  "#{Git::Revision.commit}#{Git::Revision.dirty? ? "-dirty" : ""}"
end

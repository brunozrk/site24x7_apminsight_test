# Holds the major and minor versions of the agent
# These values are used in gemspec and in agent communication
# This is one point change, no need to update version numbers at multiple places
#
# NOTE: Changing version in 'VERSION' file is optional.

module ManageEngine
  class APMInsight
    VERSION = '1.6.2'
    MAJOR_VERSION = '1.6'
    MINOR_VERSION = '2'
  end
end
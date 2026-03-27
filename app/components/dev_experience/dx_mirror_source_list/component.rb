# frozen_string_literal: true

module DevExperience
  class DxMirrorSourceList::Component < ApplicationViewComponent
    option :paths
    option :label, default: -> { "Files" }
  end
end

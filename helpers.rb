#!/usr/bin/env ruby

module Helpers
  def self.format_timestamp (timestamp)
    # Formats a long datetimestamp into a nice, short one
    DateTime.parse(timestamp).strftime("on %a %b %d, %Y at %I:%M%P")
  end
end

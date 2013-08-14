module Gtk

	# Add a way to associate user data to a Gtk object
  class Object < GLib::InitiallyUnowned

    attr_accessor :user_data

  end

end

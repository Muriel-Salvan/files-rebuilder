module FilesRebuilder

  class GUIFactory

    # Constructor
    def initialize
      require 'filesrebuilder/GUIHandler'
      # Map of GUI glade contents, by gui_id
      @gui_contents = {}
    end

    # Set the GUI controller
    #
    # Parameters::
    # * *gui_controller* (_GUIController_): The GUI controller
    def gui_controller=(gui_controller)
      @gui_controller = gui_controller
    end

    # Get a new widget associated to the given GUI ID
    #
    # Parameters::
    # * *gui_id* (_String_): The GUI widget ID
    # Result::
    # * <em>Gtk::Widget</em>: The corresponding widget
    def new_widget(gui_id)
      # Get the cached Glade content
      if !@gui_contents.has_key?(gui_id)
        require "filesrebuilder/GUI/#{gui_id}"
        File.open("#{File.dirname(__FILE__)}/GUI/#{gui_id}.glade", 'r') do |file|
          @gui_contents[gui_id] = file.read
        end
      end
      # Use a builder to create it
      gtk_builder = Gtk::Builder.new
      gtk_builder.add_from_string(@gui_contents[gui_id])
      new_widget = gtk_builder[gui_id.split('/')[-1]]
      # Associate its methods
      new_widget.extend(GUIHandler)
      new_widget.extend(eval("FilesRebuilder::GUI::#{gui_id.gsub('/', '::')}"))
      # Initialize common properties
      new_widget.init(self, @gui_controller, gtk_builder)
      # Connect its signals
      gtk_builder.connect_signals do |handler|
        next new_widget.method(handler)
      end

      return new_widget
    end

  end

end

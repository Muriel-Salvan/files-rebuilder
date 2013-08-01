module FilesRebuilder

  module GUI

    class ShowDir < GUIHandler

      def on_treeview_row_expanded(widget, tree_iter, tree_path)
        # If the only child has no data, it means it is a fake child, and we have to create real children
        if (tree_iter.first_child[0] == nil)
          fake_child = tree_iter.first_child
          # Create real children
          dir_info = tree_iter[0][1]
          dir_info.sub_dirs.each do |child_dir_name, child_dir_info|
            add_obj_info(widget.model, tree_iter, child_dir_name, child_dir_info)
          end
          dir_info.files.each do |child_file_name, child_file_info|
            add_obj_info(widget.model, tree_iter, child_file_name, child_file_info)
          end
          # Delete the fake child (do it after inserting others otherwise expansion will be cancelled)
          widget.model.remove(fake_child)
        end
      end

      def on_treeview_cursor_changed(widget)
        # Get the selected TreeIter
        selected_item = widget.selection.selected
        treestore = get_details_tree_view(widget.parent.parent.parent).model
        treestore.clear
        if (selected_item != nil)
          line_obj_info = selected_item[0][1]
          if (line_obj_info.is_a?(Model::DirInfo))
            line = treestore.append(nil)
            line[0] = 'Number of files'
            line[1] = line_obj_info.files.size.to_s
            line = treestore.append(nil)
            line[0] = 'Number of sub-directories'
            line[1] = line_obj_info.sub_dirs.size.to_s
          elsif (line_obj_info.filled)
            line = treestore.append(nil)
            line[0] = 'Already scanned?'
            line[1] = 'Yes'
            line = treestore.append(nil)
            line[0] = 'Date'
            line[1] = line_obj_info.date.strftime('%Y-%m-%d %H:%M:%S')
            line = treestore.append(nil)
            line[0] = 'Size'
            line[1] = line_obj_info.size.to_s
            line = treestore.append(nil)
            line[0] = 'CRC global'
            line[1] = line_obj_info.get_crc
            line = treestore.append(nil)
            line[0] = 'CRC list'
            line[1] = line_obj_info.crc_list.join(', ')
            segments_line = treestore.append(nil)
            segments_line[0] = "#{line_obj_info.segments.size} segments"
            segments_line[1] = ''
            line_obj_info.segments.each_with_index do |segment, idx_segment|
              segment_line = treestore.append(segments_line)
              segment_line[0] = "Segment ##{idx_segment}: [#{segment.begin_offset}-#{segment.end_offset}]"
              segment_line[1] = "#{segment.extensions.join(', ')}#{segment.truncated ? ' (Truncated)' : ''} - #{segment.metadata.size} metadata"
              segment.metadata.each do |metadata_key, metadata_value|
                line = treestore.append(segment_line)
                line[0] = metadata_key.to_s
                line[1] = metadata_value.to_s
              end
            end
          else
            line = treestore.append(nil)
            line[0] = 'Already scanned?'
            line[1] = 'No'
          end
        end
      end

      # Set the directory to be displayed
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      # * *dir_name* (_String_): Directory to display
      # * *dir_info* (<em>Model::DirInfo</em>): Corresponding DirInfo
      def set_dir_name(widget, dir_name, dir_info)
        # Create the TreeStore
        treestore = Gtk::TreeStore.new(Model::DirInfo)
        add_obj_info(treestore, nil, dir_name, dir_info)
        # Assign TreeStore to the view
        view = get_tree_view(widget)
        view.model = treestore
        # Set renderers
        # == Icon ==
        view_column_name = Gtk::TreeViewColumn.new
        view_column_name.title = 'Name'
        view_column_name.resizable = true
        cell_renderer_icon = Gtk::CellRendererPixbuf.new
        view_column_name.pack_start(cell_renderer_icon, false)
        view_column_name.set_cell_data_func(cell_renderer_icon) do |column, renderer, model, iter|
          line_obj_info = iter[0][1]
          if (line_obj_info.is_a?(Model::DirInfo))
            renderer.stock_id = Gtk::Stock::DIRECTORY
          elsif (line_obj_info.filled)
            if ((line_obj_info.segments.size == 1) and
                (line_obj_info.segments[0].extensions != [:unknown]) and
                (!line_obj_info.segments[0].truncated))
              renderer.stock_id = Gtk::Stock::APPLY
            else
              renderer.stock_id = Gtk::Stock::DIALOG_WARNING
            end
          else
            renderer.stock_id = Gtk::Stock::DIALOG_QUESTION
          end
        end
        # == Name ==
        cell_renderer_name = Gtk::CellRendererText.new
        cell_renderer_name.foreground = 'grey'
        view_column_name.pack_start(cell_renderer_name, true)
        view.append_column(view_column_name)
        view_column_name.set_cell_data_func(cell_renderer_name) do |column, renderer, model, iter|
          line_obj_info = iter[0][1]
          if (line_obj_info.is_a?(Model::DirInfo))
            renderer.text = "#{iter[0][0]}/"
            renderer.foreground_set = false
            renderer.weight = Pango::WEIGHT_BOLD
          else
            renderer.text = iter[0][0]
            renderer.foreground_set = (!line_obj_info.filled)
            renderer.weight = Pango::WEIGHT_NORMAL
          end
          # Some debugging info
          renderer.text = "@#{line_obj_info.object_id} - " + renderer.text
        end
        # == Date ==
        cell_renderer_date = Gtk::CellRendererText.new
        view_column_date = Gtk::TreeViewColumn.new('Date', cell_renderer_date)
        view.append_column(view_column_date)
        view_column_date.set_cell_data_func(cell_renderer_date) do |column, renderer, model, iter|
          line_obj_info = iter[0][1]
          if ((line_obj_info.is_a?(Model::DirInfo)) or
              (!line_obj_info.filled))
            renderer.text = ''
          else
            renderer.text = line_obj_info.date.strftime('%Y-%m-%d %H:%M:%S')
          end
        end
        # == Size ==
        cell_renderer_size = Gtk::CellRendererText.new
        view_column_size = Gtk::TreeViewColumn.new('Size', cell_renderer_size)
        view.append_column(view_column_size)
        view_column_size.set_cell_data_func(cell_renderer_size) do |column, renderer, model, iter|
          line_obj_info = iter[0][1]
          if (line_obj_info.is_a?(Model::DirInfo))
            renderer.text = "#{line_obj_info.sub_dirs.size} subdirs, #{line_obj_info.files.size} files"
          elsif (line_obj_info.filled)
            renderer.text = line_obj_info.size.to_s
          else
            renderer.text = ''
          end
        end
        # == Segments ==
        cell_renderer_segments = Gtk::CellRendererText.new
        view_column_segments = Gtk::TreeViewColumn.new('Segments', cell_renderer_segments)
        view.append_column(view_column_segments)
        view_column_segments.set_cell_data_func(cell_renderer_segments) do |column, renderer, model, iter|
          line_obj_info = iter[0][1]
          if ((line_obj_info.is_a?(Model::DirInfo)) or
              (!line_obj_info.filled))
            renderer.text = ''
          else
            renderer.text = "#{line_obj_info.segments.map { |segment| "[#{segment.extensions.join(',')}#{segment.truncated ? '(truncated)' : ''}]" }.join(' ')}"
          end
        end
        # Create a TreeStore for the details pane
        details_tree_view = get_details_tree_view(widget)
        details_treestore = Gtk::TreeStore.new(String, String)
        details_tree_view.model = details_treestore
        # == Property ==
        cell_renderer_property = Gtk::CellRendererText.new
        view_column_property = Gtk::TreeViewColumn.new('Property', cell_renderer_property)
        details_tree_view.append_column(view_column_property)
        view_column_property.set_cell_data_func(cell_renderer_property) do |column, renderer, model, iter|
          renderer.text = iter[0]
        end
        # == Value ==
        cell_renderer_value = Gtk::CellRendererText.new
        view_column_value = Gtk::TreeViewColumn.new('Value', cell_renderer_value)
        details_tree_view.append_column(view_column_value)
        view_column_value.set_cell_data_func(cell_renderer_value) do |column, renderer, model, iter|
          renderer.text = iter[1]
        end
      end

      private

      # Get the tree view
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      def get_tree_view(widget)
        return widget.children[0].children[2].children[0]
      end

      # Get the details tree view
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      def get_details_tree_view(widget)
        return widget.children[0].children[3].children[0].children[0].children[0]
      end

      # Create items for a given object model in a treestore
      #
      # Parameters::
      # * *treestore* (<em>Gtk::TreeStore</em>): The TreeStore to complete
      # * *parent_elem* (<em>Gtk::TreeIter</em>): Element to create the DirInfo into
      # * *obj_name* (_String_): Directory name
      # * *obj_info* (_Object_): The model object to add to the treestore. Can be DirInfo or FileInfo.
      def add_obj_info(treestore, parent_elem, obj_name, obj_info)
        new_elem = treestore.append(parent_elem)
        new_elem[0] = [ obj_name, obj_info ]
        if ((obj_info.is_a?(Model::DirInfo)) and
            ((!obj_info.sub_dirs.empty?) or
             (!obj_info.files.empty?)))
          # Create a fake child just for being able to expand it
          treestore.append(new_elem)[0] = nil
        end
      end

    end

  end

end

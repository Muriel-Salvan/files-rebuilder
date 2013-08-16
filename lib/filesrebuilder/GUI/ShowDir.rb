module FilesRebuilder

  module GUI

    class ShowDir < GUIHandler

      def on_treeview_row_expanded(widget, tree_iter, tree_path)
        # If the only child has no data, it means it is a fake child, and we have to create real children
        if (tree_iter.first_child[0] == false)
          fake_child = tree_iter.first_child
          # Create real children
          obj_info = tree_iter[0]
          if (obj_info.is_a?(Model::DirInfo))
            # Directory
            obj_info.sub_dirs.values.each do |child_dir_info|
              add_obj_info(widget.model, tree_iter, child_dir_info)
            end
            obj_info.files.values.each do |child_file_info|
              add_obj_info(widget.model, tree_iter, child_file_info)
            end
          else
            file_info = obj_info
            segment_index = nil
            if (obj_info.is_a?(Model::SegmentPointer))
              file_info = obj_info.file_info
              segment_index = obj_info.idx_segment
            end
            # File
            src_matching_index, dst_matching_index = @gui_controller.get_matching_indexes(file_info, segment_index)
            if (!src_matching_index.empty?)
              new_elem_indexes = widget.model.append(tree_iter)
              new_elem_indexes[0] = 'Matching recovered files'
              add_matching_index_info(widget.model, new_elem_indexes, src_matching_index)
            end
            if (!dst_matching_index.empty?)
              new_elem_indexes = widget.model.append(tree_iter)
              new_elem_indexes[0] = 'Matching files to be rebuilt'
              add_matching_index_info(widget.model, new_elem_indexes, dst_matching_index)
            end
          end
          # Delete the fake child (do it after inserting others otherwise expansion will be cancelled)
          widget.model.remove(fake_child)
        end
      end

      def on_treeview_cursor_changed(widget)
        # Get the selected TreeIter
        selected_item = widget.selection.selected
        treestore = get_details_tree_view(widget.parent.parent.parent.parent).model
        treestore.clear
        if (selected_item != nil)
          line_obj_info = selected_item[0]
          if (line_obj_info.is_a?(Model::DirInfo))
            line = treestore.append(nil)
            line[0] = 'Number of files'
            line[1] = line_obj_info.files.size.to_s
            line = treestore.append(nil)
            line[0] = 'Number of sub-directories'
            line[1] = line_obj_info.sub_dirs.size.to_s
          elsif ((line_obj_info.is_a?(Model::SegmentPointer)) or
                 (line_obj_info.is_a?(Model::FileInfo)))
            file_info = ((line_obj_info.is_a?(Model::SegmentPointer)) ? line_obj_info.file_info : line_obj_info)
            if (file_info.filled)
              line = treestore.append(nil)
              line[0] = 'Already scanned?'
              line[1] = 'Yes'
              line = treestore.append(nil)
              line[0] = 'Date'
              line[1] = file_info.date.strftime('%Y-%m-%d %H:%M:%S')
              line = treestore.append(nil)
              line[0] = 'Size'
              line[1] = file_info.size.to_s
              line = treestore.append(nil)
              line[0] = 'CRC global'
              line[1] = file_info.get_crc
              line = treestore.append(nil)
              line[0] = 'CRC list'
              line[1] = file_info.crc_list.join(', ')
              segments_line = treestore.append(nil)
              segments_line[0] = "#{file_info.segments.size} segments"
              segments_line[1] = ''
              file_info.segments.each_with_index do |segment, idx_segment|
                segment_line = treestore.append(segments_line)
                segment_line[0] = "Segment ##{idx_segment}: [#{segment.begin_offset}-#{segment.end_offset}]"
                segment_line[1] = "#{segment.extensions.join(', ')}#{segment.missing_previous_data ? ' (Missing previous data)' : ''}#{segment.truncated ? ' (Truncated)' : ''} (CRC: #{segment.get_crc}) - #{segment.metadata.size} metadata - CRC List: [#{segment.crc_list.join(', ')}]"
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
      end

      # Set the directory to be displayed
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      # * *dir_name* (_String_): Directory to display
      # * *dir_info* (<em>Model::DirInfo</em>): Corresponding DirInfo
      def set_dir_name(widget, dir_name, dir_info)

        # Create the main TreeStore
        treestore = Gtk::TreeStore.new(Model::DirInfo)
        add_obj_info(treestore, nil, dir_info)
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
          line_obj_info = iter[0]
          if (line_obj_info.is_a?(Model::DirInfo))
            renderer.stock_id = Gtk::Stock::DIRECTORY
          elsif (line_obj_info.is_a?(String))
            renderer.stock_id = Gtk::Stock::DISCARD
          elsif (line_obj_info.is_a?(Model::SegmentPointer))
            renderer.stock_id = Gtk::Stock::INDEX
          elsif (line_obj_info.filled)
            if ((line_obj_info.segments.size == 1) and
                (line_obj_info.segments[0].extensions != [:unknown]) and
                (!line_obj_info.segments[0].truncated) and
                (!line_obj_info.segments[0].missing_previous_data))
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
          line_obj_info = iter[0]
          if (line_obj_info.is_a?(Model::DirInfo))
            renderer.text = "#{line_obj_info.base_name}/"
            renderer.foreground_set = false
            renderer.weight = Pango::WEIGHT_BOLD
          elsif (line_obj_info.is_a?(String))
            renderer.text = line_obj_info
            renderer.foreground_set = false
            renderer.weight = Pango::WEIGHT_NORMAL
          elsif (line_obj_info.is_a?(Model::SegmentPointer))
            renderer.text = "#{line_obj_info.file_info.base_name} - Segment ##{line_obj_info.idx_segment}"
            renderer.foreground_set = false
            renderer.weight = Pango::WEIGHT_NORMAL
          else
            renderer.text = line_obj_info.base_name
            renderer.foreground_set = (!line_obj_info.filled)
            renderer.weight = Pango::WEIGHT_NORMAL
          end
          # Some debugging info
          renderer.text = "@#{line_obj_info.object_id} - " + renderer.text if debug_activated?
        end
        # == Date ==
        cell_renderer_date = Gtk::CellRendererText.new
        view_column_date = Gtk::TreeViewColumn.new('Date', cell_renderer_date)
        view.append_column(view_column_date)
        view_column_date.set_cell_data_func(cell_renderer_date) do |column, renderer, model, iter|
          line_obj_info = iter[0]
          if ((line_obj_info.is_a?(Model::FileInfo)) and
              (line_obj_info.filled))
            renderer.text = line_obj_info.date.strftime('%Y-%m-%d %H:%M:%S')
          elsif (line_obj_info.is_a?(Model::SegmentPointer))
            renderer.text = line_obj_info.file_info.date.strftime('%Y-%m-%d %H:%M:%S')
          else
            renderer.text = ''
          end
        end
        # == Size ==
        cell_renderer_size = Gtk::CellRendererText.new
        view_column_size = Gtk::TreeViewColumn.new('Size', cell_renderer_size)
        view.append_column(view_column_size)
        view_column_size.set_cell_data_func(cell_renderer_size) do |column, renderer, model, iter|
          line_obj_info = iter[0]
          if (line_obj_info.is_a?(Model::DirInfo))
            renderer.text = "#{line_obj_info.sub_dirs.size} subdirs, #{line_obj_info.files.size} files"
          elsif ((line_obj_info.is_a?(Model::FileInfo)) and
                 (line_obj_info.filled))
            renderer.text = line_obj_info.size.to_s
          elsif (line_obj_info.is_a?(Model::SegmentPointer))
            segment = line_obj_info.segment
            renderer.text = (segment.end_offset - segment.begin_offset).to_s
          else
            renderer.text = ''
          end
        end
        # == Segments ==
        cell_renderer_segments = Gtk::CellRendererText.new
        view_column_segments = Gtk::TreeViewColumn.new('Segments', cell_renderer_segments)
        view.append_column(view_column_segments)
        view_column_segments.set_cell_data_func(cell_renderer_segments) do |column, renderer, model, iter|
          line_obj_info = iter[0]
          if ((line_obj_info.is_a?(Model::FileInfo)) and
              (line_obj_info.filled))
            renderer.text = "#{line_obj_info.segments.map { |segment| "[#{segment.extensions.join(',')}#{segment.truncated ? '(truncated)' : ''}]" }.join(' ')}"
          else
            renderer.text = ''
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
        return widget.children[0].children[2].children[0].children[0]
      end

      # Get the details tree view
      #
      # Parameters::
      # * *widget* (<em>Gtk::Widget</em>): The ShowDir widget
      def get_details_tree_view(widget)
        return widget.children[0].children[2].children[1].children[0].children[0].children[0]
      end

      # Create items for a given object model in a treestore
      #
      # Parameters::
      # * *treestore* (<em>Gtk::TreeStore</em>): The TreeStore to complete
      # * *parent_elem* (<em>Gtk::TreeIter</em>): Element to create the DirInfo into
      # * *obj_info* (_Object_): The model object to add to the treestore. Can be DirInfo, FileInfo or a String.
      def add_obj_info(treestore, parent_elem, obj_info)
        new_elem = treestore.append(parent_elem)
        new_elem[0] = obj_info
        if (((obj_info.is_a?(Model::FileInfo)) and
             (obj_info.filled)) or
            (obj_info.is_a?(Model::SegmentPointer)) or
            ((obj_info.is_a?(Model::DirInfo)) and
             ((!obj_info.sub_dirs.empty?) or
              (!obj_info.files.empty?))))
          # Create a fake child just for being able to expand it
          treestore.append(new_elem)[0] = false
        end
      end

      # Add matching index objects in a TreeStore
      #
      # Parameters::
      # * *treestore* (<em>Gtk::TreeStore</em>): The TreeStore to complete
      # * *parent_elem* (<em>Gtk::TreeIter</em>): Element to create the DirInfo into
      # * *matching_index* (_MatchingIndex_): The model matching index information
      def add_matching_index_info(treestore, parent_elem, matching_index)
        matching_index.indexes.each do |index_name, data_map|
          new_elem_index = treestore.append(parent_elem)
          nbr_matching_files_per_index = 0
          data_map.each do |data, lst_matching_fileinfo|
            new_elem_data = treestore.append(new_elem_index)
            lst_matching_fileinfo.each do |pointer|
              add_obj_info(treestore, new_elem_data, pointer)
            end
            new_elem_data[0] = "#{data.inspect} - #{lst_matching_fileinfo.size} matching files"
            nbr_matching_files_per_index += lst_matching_fileinfo.size
          end
          new_elem_index[0] = "#{index_name.to_s} matching - #{data_map.size} data - #{nbr_matching_files_per_index} matching files"
        end
      end

    end

  end

end

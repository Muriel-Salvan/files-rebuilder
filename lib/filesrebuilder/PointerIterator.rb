module FilesRebuilder

	# Provide an iterator interface used for ComparePointer GUI
  class PointerIterator

  	# Constructor
  	def initialize
  		@last_given = nil
  		@pointer = nil
  		@matching_pointers = nil
      self.reset
  	end

  	# Initialize the iterator with a single pointer and its list of matching pointers
  	#
  	# Parameters::
    # * *pointer* (_FileInfo_ or _SegmentPointer_): Pointer to be compared
    # * *matching_pointers* (<em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>): The sorted list of matching pointers, along with their matching index information
    def set_from_single(pointer, matching_pointers)
    	@pointer = pointer
    	@matching_pointers = matching_pointers
    end

    # Initialize the iterator with a list of dirinfos
    #
    # Parameters::
    # * *gui_controller* (_GUIController_): The controller
    # * *lst_dirinfo* (<em>list<DirInfo></em>): List of dirinfo to consider
    # * *index* (_MatchingIndex_): Index of the possibly matching files
    # * *matching_selection* (_MatchingSelection_): Current user selection of matching files
    def set_from_dirinfos(gui_controller, lst_dirinfo, index, matching_selection)
      @gui_controller = gui_controller
    	@lst_dirinfo = lst_dirinfo
    	@index = index
    	@matching_selection = matching_selection
    end

    # Reset the iterator to its initial state
    # Prerequisite: This is useful only for iterators set from dirinfo lists
    def reset
      @last_dir = []
      @last_file = nil
      @last_idx_segment = nil
      @last_idx_dirinfo = nil
      @finished = false
    end

    # Get next pointer and matching pointers
    #
    # Parameters::
    # * *skip_matched* (_Boolean_): Do we skip already matched pointers?
    # * *search_forward* (_Boolean_): Do we search forward?
    # Result::
    # * <em>(_FileInfo_ | _SegmentPointer_)</em>: The pointer, or nil if none
    # * <em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>: The sorted list of matching pointers, along with their matching index information
    def next(skip_matched, search_forward)
    	next_pointer = nil
    	next_matching_pointers = nil

  		if (@pointer != nil)
        # Iterator has been setup with a single pointer
        if (@last_given == nil)
  			 next_pointer = @pointer
  			 next_matching_pointers = @matching_pointers
  			 @last_given = next_pointer
        else
          @last_given = nil
        end
  		elsif (@lst_dirinfo != nil)
        # Iterator has been setup with a list of dirinfo
        if (!@finished)
          @last_idx_dirinfo = (search_forward ? 0 : (@lst_dirinfo.size - 1)) if (@last_idx_dirinfo == nil)
          while ((search_forward and
                  (@last_idx_dirinfo < @lst_dirinfo.size)) or
                 (!search_forward and
                  (@last_idx_dirinfo >= 0)))
            next_pointer, next_matching_pointers, @last_dir, @last_file, @last_idx_segment = get_next_unmatched_pointer_from_dirinfo(@lst_dirinfo[@last_idx_dirinfo], @last_dir, @last_file, @last_idx_segment, skip_matched, search_forward)
            if (next_pointer != nil)
              log_debug "[PointerIterator] - #{search_forward ? 'Next' : 'Previous'} pointer from dirinfo ##{@last_idx_dirinfo}: #{@last_dir.join('/')}/#{@last_file} ##{@last_idx_segment.inspect}"
              break
            end
            @last_idx_dirinfo += (search_forward ? 1 : -1)
          end
          @finished = (next_pointer == nil)
        end
      else
        raise 'PointerIterator has not been setup before calling next'
  		end

  		return next_pointer, next_matching_pointers
    end

    private

    # Get the next unmatched pointer from a dirinfo.
    # Parse recursively its sub-directories.
    # Provide the last directory hierarchy and file name that precedes the pointer to return.
    #
    # Parameters::
    # * *dirinfo* (_DirInfo_): The dirinfo in which we start the search
    # * *last_dir_hierarchy* (<em>list< String ></em>): The list of directory base names that lead to the last file processed from this dirinfo
    # * *last_file* (_String_): Last file base name that has been processed from this dirinfo and its hierarchy. Can be nil if none.
    # * *last_idx_segment* (_Fixnum_): Last segment index that has been processed from this file. Can be nil if none.
    # * *skip_matched* (_Boolean_): Do we skip already matched pointers?
    # * *search_forward* (_Boolean_): Do we search forward?
    # Result::
    # * <em>(_FileInfo_ | _SegmentPointer_)</em>: The pointer, or nil if none
    # * <em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>: The sorted list of matching pointers, along with their matching index information
    # * <em>list< String ></em>: The directory hierarchy leading to the returned pointer
    # * _String_: The base file name of the file leading to the returned pointer
    # * _Fixnum_: The segment index leading to the returned pointer. Can be nil for a whole file.
    def get_next_unmatched_pointer_from_dirinfo(dirinfo, last_dir_hierarchy, last_file, last_idx_segment, skip_matched, search_forward)
      pointer = nil
      matching_pointers = nil
      new_dir_hierarchy = nil
      new_file = nil
      new_idx_segment = nil

      # First pass on the sub hierarchy if the iteration begins there
      if !last_dir_hierarchy.empty?
        last_sub_dir = last_dir_hierarchy[0]
        pointer, matching_pointers, sub_dir_hierarchy, new_file, new_idx_segment = get_next_unmatched_pointer_from_dirinfo(dirinfo.sub_dirs[last_sub_dir], last_dir_hierarchy[1..-1], last_file, last_idx_segment, skip_matched, search_forward)
        new_dir_hierarchy = [last_sub_dir] + sub_dir_hierarchy if (pointer != nil)
      end
      if (pointer == nil)
        if search_forward
          if last_dir_hierarchy.empty?
            # Consider files from this dirinfo
            pointer, matching_pointers, new_file, new_idx_segment = get_next_unmatched_pointer_from_dirinfo_files(dirinfo, last_file, last_idx_segment, skip_matched, search_forward)
            new_dir_hierarchy = [] if (pointer != nil)
          end
          if (pointer == nil)
            # We need to consider sub-directories
            lst_sorted_sub_dirs = dirinfo.sub_dirs.sort_by { |dir_base_name, _| dir_base_name }
            idx_sub_dir = nil
            if last_dir_hierarchy.empty?
              idx_sub_dir = 0
            else
              last_sub_dir = last_dir_hierarchy[0]
              idx_sub_dir = lst_sorted_sub_dirs.index { |dir_base_name, _| dir_base_name == last_sub_dir } + 1
            end
            # Start considering sub-directories from idx_sub_dir
            while (idx_sub_dir < lst_sorted_sub_dirs.size)
              sub_dir_name, sub_dir_info = lst_sorted_sub_dirs[idx_sub_dir]
              pointer, matching_pointers, sub_dir_hierarchy, new_file, new_idx_segment = get_next_unmatched_pointer_from_dirinfo(sub_dir_info, [], nil, nil, skip_matched, search_forward)
              if (pointer != nil)
                new_dir_hierarchy = [sub_dir_name] + sub_dir_hierarchy
                break
              end
              idx_sub_dir += 1
            end
          end
        else
          if (!last_dir_hierarchy.empty? or
              (last_file == nil))
            # Consider sub directories first
            lst_sorted_sub_dirs = dirinfo.sub_dirs.sort_by { |dir_base_name, _| dir_base_name }
            idx_sub_dir = nil
            if last_dir_hierarchy.empty?
              # Here we have to parse all sub-directories
              idx_sub_dir = lst_sorted_sub_dirs.size - 1
            else
              # Here we have already parsed some of them
              last_sub_dir = last_dir_hierarchy[0]
              idx_sub_dir = lst_sorted_sub_dirs.index { |dir_base_name, _| dir_base_name == last_sub_dir } - 1
            end
            # Start considering sub-directories from idx_sub_dir
            while (idx_sub_dir >= 0)
              sub_dir_name, sub_dir_info = lst_sorted_sub_dirs[idx_sub_dir]
              pointer, matching_pointers, sub_dir_hierarchy, new_file, new_idx_segment = get_next_unmatched_pointer_from_dirinfo(sub_dir_info, [], nil, nil, skip_matched, search_forward)
              if (pointer != nil)
                new_dir_hierarchy = [sub_dir_name] + sub_dir_hierarchy
                break
              end
              idx_sub_dir -= 1
            end
          end
          if (pointer == nil)
            # Now we can consider files
            if (!last_dir_hierarchy.empty?)
              last_file = nil
              last_idx_segment = nil
            end
            pointer, matching_pointers, new_file, new_idx_segment = get_next_unmatched_pointer_from_dirinfo_files(dirinfo, last_file, last_idx_segment, skip_matched, search_forward)
            new_dir_hierarchy = [] if (pointer != nil)
          end
        end
      end

      return pointer, matching_pointers, new_dir_hierarchy, new_file, new_idx_segment
    end

    # Get the next unmatched pointer from the files of a dirinfo.
    # Provide the last file name that precedes the pointer to return.
    #
    # Parameters::
    # * *dirinfo* (_DirInfo_): The dirinfo in which we start the search
    # * *last_file* (_String_): Last file base name that has been processed from this dirinfo and its hierarchy. Can be nil if none.
    # * *last_idx_segment* (_Fixnum_): Last segment index that has been processed from this file. Can be nil if none.
    # * *skip_matched* (_Boolean_): Do we skip already matched pointers?
    # * *search_forward* (_Boolean_): Do we search forward?
    # Result::
    # * <em>(_FileInfo_ | _SegmentPointer_)</em>: The pointer, or nil if none
    # * <em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>: The sorted list of matching pointers, along with their matching index information
    # * _String_: The base file name of the file leading to the returned pointer
    # * _Fixnum_: The segment index leading to the returned pointer. Can be nil for a whole file.
    def get_next_unmatched_pointer_from_dirinfo_files(dirinfo, last_file, last_idx_segment, skip_matched, search_forward)
      pointer = nil
      matching_pointers = nil
      new_file = nil
      new_idx_segment = nil

      lst_sorted_files = dirinfo.files.sort_by { |file_base_name, _| file_base_name }
      idx_file = nil
      idx_segment = nil
      if (last_file == nil)
        idx_file = (search_forward ? 0 : (lst_sorted_files.size - 1))
      else
        idx_file = lst_sorted_files.index { |file_base_name, _| file_base_name == last_file }
        # Also increase the idx_segment
        file_base_name, file_info = lst_sorted_files[idx_file]
        if (file_info.segments.size == 1)
          idx_file += (search_forward ? 1 : -1)
        else
          if (last_idx_segment == nil)
            # We were pointing on a multi-segment file, but on the file as a whole
            if search_forward
              idx_segment = 0
            else
              # Get the last segment of the previous file
              idx_file -= 1
              if ((idx_file >= 0) and
                  (lst_sorted_files[idx_file][1].segments.size > 1))
                idx_segment = lst_sorted_files[idx_file][1].segments.size - 1
              else
                idx_segment = nil
              end
            end
          elsif (last_idx_segment == file_info.segments.size - 1)
            # We were pointing on a multi-segment file, but on its last segment
            if search_forward
              idx_file += 1
            else
              idx_segment = last_idx_segment - 1
            end
          elsif (last_idx_segment == 0)
            # We were pointing on a multi-segment file, but on its first segment
            idx_segment = last_idx_segment + 1 if search_forward
          else
            # We were pointing on a multi-segment file in the middle of its segments
            idx_segment = last_idx_segment + (search_forward ? 1 : -1)
          end
        end
      end
      # Here, idx_file and idx_segment point on the next file/segment to consider
      while ((search_forward and
              (idx_file < lst_sorted_files.size)) or
             (!search_forward and
              (idx_file >= 0)))
        file_base_name, file_info = lst_sorted_files[idx_file]
        if search_forward
          if (idx_segment == nil)
            # Consider the file as a whole
            matching_pointers = get_matching_pointers(file_info, skip_matched)
            if (matching_pointers != nil)
              # We got our next pointer!
              pointer = file_info
              new_file = file_base_name
              new_idx_segment = nil
              break
            end
            # Now point on its first segment if needed
            idx_segment = 0 if (file_info.segments.size > 1)
          end
          # Eventually consider segments
          if (file_info.segments.size > 1)
            while (idx_segment < file_info.segments.size)
              segment_pointer = Model::SegmentPointer.new(file_info, idx_segment)
              matching_pointers = get_matching_pointers(segment_pointer, skip_matched)
              if (matching_pointers != nil)
                # We got our next pointer!
                pointer = segment_pointer
                new_file = file_base_name
                new_idx_segment = idx_segment
                break
              end
              idx_segment += 1
            end
            break if (pointer != nil)
          end
        else
          if (idx_segment != nil)
            # First consider segments
            while (idx_segment >= 0)
              segment_pointer = Model::SegmentPointer.new(file_info, idx_segment)
              matching_pointers = get_matching_pointers(segment_pointer, skip_matched)
              if (matching_pointers != nil)
                # We got our next pointer!
                pointer = segment_pointer
                new_file = file_base_name
                new_idx_segment = idx_segment
                break
              end
              idx_segment -= 1
            end
            break if (pointer != nil)
          end
          # Consider the file as a whole
          matching_pointers = get_matching_pointers(file_info, skip_matched)
          if (matching_pointers != nil)
            # We got our next pointer!
            pointer = file_info
            new_file = file_base_name
            new_idx_segment = nil
            break
          end
        end
        # Here we did not find anything in this file: look for the next
        idx_file += (search_forward ? 1 : -1)
        if (search_forward or
            (idx_file == -1) or
            (lst_sorted_files[idx_file][1].segments.size == 1))
          idx_segment = nil
        else
          # Make the segment index point on the last segment
          idx_segment = lst_sorted_files[idx_file][1].segments.size - 1
        end
      end

      return pointer, matching_pointers, new_file, new_idx_segment
    end

    # Get matching pointers for a given pointer.
    # Returns nil if the pointer is already matched or if no matching pointers have been found
    #
    # Parameters::
    # * *pointer* <em>(_FileInfo_ | _SegmentPointer_)</em>: The pointer
    # * *skip_matched* (_Boolean_): Do we skip already matched pointers?
    # Result::
    # * <em>list< [ (_FileInfo_ | _SegmentPointer_), MatchingIndexSinglePointer ] ></em>: The sorted list of matching pointers, along with their matching index information
    def get_matching_pointers(pointer, skip_matched)
      if (skip_matched and
          @matching_selection.matching_pointers.has_key?(pointer))
        return nil
      else
        matching_pointers = @gui_controller.get_matching_info(pointer, @index).matching_files(@gui_controller.options[:score_min]).sort_by { |_, matching_file_info| -matching_file_info.score }
        return (matching_pointers.empty? ? nil : matching_pointers)
      end
    end

  end

end

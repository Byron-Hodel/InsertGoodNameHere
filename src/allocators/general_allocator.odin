package allocators

import "core:runtime"
import "core:mem"
//import "core:fmt"

import "vendor:wasm/js"

Allocator_Error :: runtime.Allocator_Error
Allocator_Mode :: runtime.Allocator_Mode

// A linked list node which describes a block of memory
// that can be used in allocating memory
// two free list nodes should never be contiguous in
// memory and should instead be coalesced to form one whole block
Free_List_Node :: struct {
    prev:      ^Free_List_Node,
    next:      ^Free_List_Node,
    size: int,
}

// describes the amount of padding before and after the allocation
// padding is added so that no bytes go unaccounted for when
// allocating and freeing memory,
// padding is required when the amount of bytes leftover is less
// than the amount required for a Free_List_Node
Allocation_Header :: struct {
    begin_padding: u8, // padding from beginning of block to beginning of header
    end_padding:   u8,
}

// used to keep track of non-contiguous chunks of memory
// used by the allocator, this is particularly helpful when
// we need to free all the allocated memory
Block :: struct {
    next: ^Block,
    size: int,
}

General_Allocator_Data :: struct {
    total_size: int,
    total_used: int,
    free_list: ^Free_List_Node,
    free_list_count: u32,
    blocks: ^Block, // keeps track of non-contiguous blocks of memory
    block_count: u32,
}



general_init :: proc(general: ^General_Allocator_Data, starting_size: int) -> Allocator_Error {
    starting_page_count := (starting_size+size_of(Block)) / js.PAGE_SIZE
    if ((starting_page_count+size_of(Block)) & (js.PAGE_SIZE)) > 0 {
        starting_page_count += 1
    }
    block := js.page_alloc(starting_page_count) or_return
    
    general.total_size = len(block) - size_of(Block)
    general.total_used = 0
    general.free_list = cast(^Free_List_Node)mem.ptr_offset(raw_data(block), size_of(Block))
    general.free_list^ = {
        prev = nil,
        next = nil,
        size = general.total_size,
    }
    general.free_list_count = 1

    general.blocks = cast(^Block)raw_data(block)
    general.blocks^ = {
        next = nil,
        size = len(block),
    }
    general.block_count = 1

    return nil
}

general_alloc :: proc(
    general: ^General_Allocator_Data,
    size: int,
    alignment: int,
) -> ([]byte, Allocator_Error) {
    // preliminary check on remaining memory grow if needed
    if general.total_size - general.total_used <= size {
        general_grow(general, size)
    }

    // Find best fit node
    best_node: ^Free_List_Node
    begin_padding: int
    tmp_node:  ^Free_List_Node = general.free_list
    if general.free_list_count == 0 {
        // should never happen
        panic("Free List Should Not Be Empty!!!")
    }
    
    for tmp_node != nil {
        defer tmp_node = tmp_node.next

        pad := (int(uintptr(tmp_node)) + size_of(Allocation_Header)) & (alignment-1)
        if pad >= size_of(Allocation_Header) {
            pad -= size_of(Allocation_Header)
        }

        if tmp_node.size < size + pad + size_of(Allocation_Header) {
            continue
        } 

        // TODO: maybe consider the amount of memory left over after splitting when selecting the best fit
        if best_node != nil {
            if tmp_node.size < best_node.size {
                best_node = tmp_node
                begin_padding = pad
            }
        }
        else {
            best_node = tmp_node
            begin_padding = pad
        }
    }

    // grow total memory (when needed)

    if best_node == nil {
        // note: memory may be fragmented
        general_grow(general, size)
        return general_alloc(general, size, alignment)
    }

    // Split Block (when needed) and setup allocation header
    best_node_cpy: Free_List_Node = best_node^ // allocation header may override free node data
    alloc_header := cast(^Allocation_Header)mem.ptr_offset(cast(^byte)best_node, begin_padding)
    data := cast([^]byte)mem.ptr_offset(alloc_header, 1)
    end_padding_ptr := mem.ptr_offset(data, size)
    end_padding: int = best_node_cpy.size - size - begin_padding

    if begin_padding >= size_of(Free_List_Node) {
        alloc_header.begin_padding = 0
        // the new node is located in the same location as the best node
        new_node := best_node
        new_node.size = begin_padding
        new_node.prev = best_node_cpy.prev
        best_node_cpy.prev = new_node
        new_node.next = best_node_cpy.next

        if new_node.next != nil {
            new_node.next.prev = new_node
        }
        general.free_list_count += 1

        general_coalesce(general, new_node)
    }
    else {
        alloc_header.begin_padding = u8(begin_padding)
    }
    
    if end_padding >= size_of(Free_List_Node) {
        alloc_header.end_padding = 0
        new_node := cast(^Free_List_Node)end_padding_ptr
        new_node.size = end_padding
        new_node.prev = best_node_cpy.prev
        new_node.next = best_node_cpy.next
        best_node_cpy.next = new_node
        
        if new_node.prev != nil {
            new_node.prev.next = new_node
        }
        if new_node.next != nil {
            new_node.next.prev = new_node
        }
        general.free_list_count += 1

        general_coalesce(general, new_node)
    }
    else {
        alloc_header.end_padding = u8(end_padding)
    }

    general.total_used += size + int(alloc_header.begin_padding) + int(alloc_header.end_padding)
    general.free_list_count -= 1

    if best_node == general.free_list {
        general.free_list = best_node_cpy.next
    }

    return data[:size], nil
}

general_free :: proc(general: ^General_Allocator_Data, old_mem: rawptr, old_size: int) {
    alloc_header := mem.ptr_offset(cast(^Allocation_Header)old_mem, -1)
    node := transmute(^Free_List_Node)mem.ptr_sub(cast(^byte)alloc_header,
                                                  cast(^byte)uintptr(alloc_header.begin_padding))

    next := general.free_list
    prev: ^Free_List_Node
    for next != nil && next < node {
        prev = next
        next = next.next
    }

    // make sure to set this first in case the header gets overwritten
    node.size = int(alloc_header.begin_padding) + int(alloc_header.end_padding) + old_size
    node.prev = prev
    node.next = next

    if prev == nil {
        general.free_list = node
    }
    else {
        prev.next = node
    }
    if next != nil {
        next.prev = node
    }
    general.total_used -= node.size
    general.free_list_count += 1

    general_coalesce(general, node)
}

general_resize :: proc(
    general: ^General_Allocator_Data,
    old_mem: rawptr,
    old_size: int,
    size: int,
    alignment: int
) -> ([]byte, Allocator_Error) {
    // TODO: Impliment proper resizing
    new_mem, err := general_alloc(general, size, alignment)
    if err != nil {
        return nil, err
    }
    mem.zero(raw_data(new_mem), len(new_mem))
    mem.copy(raw_data(new_mem), old_mem, old_size)
    general_free(general, old_mem, old_size)
    return new_mem, nil
}

general_coalesce :: proc(
    general: ^General_Allocator_Data,
    free_node: ^Free_List_Node
) {
    next := free_node.next
    if next != nil {
        node_end := cast(uintptr)mem.ptr_offset(cast(^byte)free_node, free_node.size)
        if uintptr(next) == node_end {
            general.free_list_count -= 1
            free_node.next = next.next

            if free_node.next != nil {
                free_node.next.prev = free_node
            }

            free_node.size += next.size
        }
    }

    prev := free_node.prev
    if prev != nil {
        prev_end := cast(uintptr)mem.ptr_offset(cast(^byte)prev, prev.size)
        if uintptr(free_node) == prev_end {
            general.free_list_count -= 1
            prev.next = free_node.next

            if prev.next != nil {
                prev.next.prev = prev
            }

            prev.size += free_node.size
        }
    }
}

general_grow :: proc(general: ^General_Allocator_Data, required_amount: int) {
    panic("Growing Not Implimented Yet")
}

general_allocator_proc :: proc(
    allocator_data: rawptr,
    mode: Allocator_Mode,
    size: int,
    alignment: int,
    old_mem: rawptr,
    old_size: int,
    location := #caller_location,
) -> ([]byte, Allocator_Error) {
    general := cast(^General_Allocator_Data)allocator_data

    switch mode {
    case .Alloc, .Alloc_Non_Zeroed:
        data, err := general_alloc(general, size, alignment)
        if err != nil {
            return nil, err
        }
        if mode == .Alloc {
            mem.zero(raw_data(data), size)
        }
        return data, nil
	case .Free:
        general_free(general, old_mem, old_size)
	case .Free_All:
        panic("Free All Not Implimented Yet!!!")
	case .Resize:
        return general_resize(general, old_mem, old_size, size, alignment)
	case .Query_Features:
        set := (^mem.Allocator_Mode_Set)(old_mem)
        if set != nil {
            set^ = {.Alloc, .Alloc_Non_Zeroed, .Free, .Free_All, .Resize, .Query_Features}
        }
	case .Query_Info:
    }
    return nil, nil
}
